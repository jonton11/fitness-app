require "test_helper"

class HealthMetricsApiTest < ActionDispatch::IntegrationTest
  test "ingests an atomic batch of normalized health metrics" do
    assert_difference -> { HealthMetric.count }, 2 do
      post "/api/v1/health_metrics", params: health_metrics_payload
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 2, body.fetch("health_metrics").size
    assert_equal({ "created" => 2, "replayed" => 0, "deleted" => 0 }, body.fetch("meta"))
    assert_equal "healthkit", body.dig("health_metrics", 0, "source")
    assert_equal 82.4, body.dig("health_metrics", 0, "value")
    assert_equal "2026-10-10T08:00:00.000Z", body.dig("health_metrics", 0, "started_at")
  end

  test "replays client identified metrics without duplication" do
    payload = health_metrics_payload

    post "/api/v1/health_metrics", params: payload
    assert_response :created
    original_metric = HealthMetric.find(payload[:health_metrics].first[:id])
    payload[:health_metrics].first[:value] = 75

    assert_no_difference -> { HealthMetric.count } do
      post "/api/v1/health_metrics", params: payload
    end

    assert_response :success
    assert_equal({ "created" => 0, "replayed" => 2, "deleted" => 0 }, response.parsed_body.fetch("meta"))
    assert_equal 82.4, original_metric.reload.value
  end

  test "requires client generated identifiers" do
    payload = health_metrics_payload
    payload[:health_metrics].first.delete(:id)

    assert_no_difference -> { HealthMetric.count } do
      post "/api/v1/health_metrics", params: payload
    end

    assert_response :unprocessable_content
    assert_equal "id", response.parsed_body.dig("errors", 0, "field")
  end

  test "rolls back the batch when a metric is invalid" do
    existing_metric = create_health_metric(
      kind: "steps",
      ended_at: Time.zone.parse("2026-10-09 09:00:00")
    )
    payload = health_metrics_payload
    payload[:health_metrics].last[:unit] = "miles"
    payload[:deleted_health_metric_ids] = [ existing_metric.id ]

    assert_no_difference -> { HealthMetric.count } do
      post "/api/v1/health_metrics", params: payload
    end

    assert_response :unprocessable_content
    assert_equal "unit", response.parsed_body.dig("errors", 0, "field")
    assert HealthMetric.exists?(existing_metric.id)
  end

  test "applies deletions idempotently for only the current user" do
    metric = create_health_metric(kind: "steps", ended_at: Time.zone.parse("2026-10-09 09:00:00"))
    other_user = User.create!(
      email_address: "health-owner@example.com",
      password: "password-long-enough",
      password_confirmation: "password-long-enough"
    )
    other_metric = create_health_metric(
      user: other_user,
      kind: "steps",
      ended_at: Time.zone.parse("2026-10-09 09:00:00")
    )

    post "/api/v1/health_metrics", params: {
      health_metrics: [],
      deleted_health_metric_ids: [ metric.id, other_metric.id, SecureRandom.uuid ]
    }, as: :json

    assert_response :success
    assert_equal [], response.parsed_body.fetch("health_metrics")
    assert_equal({ "created" => 0, "replayed" => 0, "deleted" => 1 }, response.parsed_body.fetch("meta"))
    assert_not HealthMetric.exists?(metric.id)
    assert HealthMetric.exists?(other_metric.id)
  end

  test "ignores a client supplied source" do
    payload = health_metrics_payload
    payload[:health_metrics].first[:source] = "oura"

    post "/api/v1/health_metrics", params: payload

    assert_response :created
    assert_equal "healthkit", response.parsed_body.dig("health_metrics", 0, "source")
  end

  test "rejects invalid timestamps before ingestion" do
    payload = health_metrics_payload
    payload[:health_metrics].first[:started_at] = "this morning"

    post "/api/v1/health_metrics", params: payload

    assert_response :unprocessable_content
    error = response.parsed_body.fetch("errors").first
    assert_equal "health_metrics[0].started_at", error.fetch("field")
    assert_equal "invalid", error.fetch("code")
  end

  test "rejects empty and oversized batches" do
    post "/api/v1/health_metrics", params: { health_metrics: [] }

    assert_response :unprocessable_content
    assert_equal "health_metrics", response.parsed_body.dig("errors", 0, "field")

    post "/api/v1/health_metrics", params: {
      health_metrics: Array.new(Api::V1::HealthMetricsController::MAX_BATCH_SIZE + 1) { health_metric_payload }
    }

    assert_response :unprocessable_content
  end

  test "lists only the current user's metrics with filters and pagination" do
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password-long-enough",
      password_confirmation: "password-long-enough"
    )
    create_health_metric(kind: "steps", ended_at: Time.zone.parse("2026-10-09 09:00:00"))
    newest = create_health_metric(kind: "steps", ended_at: Time.zone.parse("2026-10-10 09:00:00"))
    create_health_metric(user: other_user, kind: "steps", ended_at: Time.zone.parse("2026-10-11 09:00:00"))
    create_health_metric(kind: "body_weight", unit: "kg", ended_at: Time.zone.parse("2026-10-12 09:00:00"))

    get "/api/v1/health_metrics", params: { kind: "steps", limit: 1 }

    assert_response :success
    body = response.parsed_body
    assert_equal [ newest.id ], body.fetch("health_metrics").pluck("id")
    assert_equal({ "limit" => 1, "offset" => 0, "total" => 2 }, body.fetch("meta"))
  end

  private

  def health_metrics_payload
    {
      health_metrics: [
        health_metric_payload(
          kind: "body_weight",
          value: 82.4,
          unit: "kg",
          started_at: "2026-10-10T08:00:00Z",
          ended_at: "2026-10-10T08:00:00Z"
        ),
        health_metric_payload
      ]
    }
  end

  def health_metric_payload(**attributes)
    {
      id: SecureRandom.uuid,
      kind: "steps",
      value: 1_250,
      unit: "count",
      started_at: "2026-10-10T08:00:00Z",
      ended_at: "2026-10-10T09:00:00Z"
    }.merge(attributes)
  end

  def create_health_metric(
    user: users(:primary),
    kind:,
    unit: "count",
    ended_at:
  )
    HealthMetric.create!(
      id: SecureRandom.uuid,
      user:,
      kind:,
      value: 1,
      unit:,
      started_at: ended_at - 1.hour,
      ended_at:
    )
  end
end
