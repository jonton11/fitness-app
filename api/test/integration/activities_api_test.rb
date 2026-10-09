require "test_helper"

class ActivitiesApiTest < ActionDispatch::IntegrationTest
  test "lists activities newest first with pagination metadata" do
    create_activity(kind: "rest_day", started_at: Time.zone.parse("2026-10-06 12:00:00"))
    create_activity(kind: "basketball", started_at: Time.zone.parse("2026-10-07 18:00:00"))

    get "/api/v1/activities", params: { limit: 1 }

    assert_response :success
    body = response.parsed_body
    assert_equal [ "basketball" ], body.fetch("activities").map { |activity| activity.fetch("kind") }
    assert_equal({ "limit" => 1, "offset" => 0, "total" => 2 }, body.fetch("meta"))
  end

  test "creates a manual activity" do
    id = SecureRandom.uuid

    assert_difference -> { Activity.count }, 1 do
      post "/api/v1/activities", params: activity_payload(id:)
    end

    assert_response :created
    activity = response.parsed_body.fetch("activity")
    assert_equal id, activity.fetch("id")
    assert_equal "basketball", activity.fetch("kind")
    assert_equal "manual", activity.fetch("source")
    assert_equal "2026-10-07T18:00:00.000Z", activity.fetch("started_at")
    assert_equal "2026-10-07T19:12:00.000Z", activity.fetch("ended_at")
    assert_equal [ "Lower Body", "Cardio" ], activity.fetch("focus_tags")
    assert_equal "Pickup game", activity.fetch("notes")
  end

  test "replays a client identified activity without duplication" do
    id = SecureRandom.uuid
    payload = activity_payload(id:)

    post "/api/v1/activities", params: payload

    assert_response :created
    assert_no_difference -> { Activity.count } do
      post "/api/v1/activities", params: payload
    end
    assert_response :success
    assert_equal id, response.parsed_body.dig("activity", "id")
  end

  test "does not accept a client supplied source" do
    payload = activity_payload
    payload[:activity][:source] = "oura"

    post "/api/v1/activities", params: payload

    assert_response :created
    assert_equal "manual", response.parsed_body.dig("activity", "source")
  end

  test "returns validation errors" do
    post "/api/v1/activities", params: {
      activity: { kind: "run", started_at: "2026-10-07T18:00:00Z" }
    }

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("errors"), {
      "field" => "kind",
      "code" => "inclusion",
      "message" => "Kind is not included in the list"
    }
  end

  test "returns a field error for an invalid timestamp" do
    post "/api/v1/activities", params: {
      activity: { kind: "recovery", started_at: "tonight" }
    }

    assert_response :unprocessable_content
    assert_equal "started_at", response.parsed_body.dig("errors", 0, "field")
    assert_equal "invalid", response.parsed_body.dig("errors", 0, "code")
  end

  test "shows an activity" do
    activity = create_activity(kind: "recovery")

    get "/api/v1/activities/#{activity.id}"

    assert_response :success
    assert_equal activity.id, response.parsed_body.dig("activity", "id")
  end

  test "returns not found for a missing activity" do
    get "/api/v1/activities/00000000-0000-0000-0000-000000000000"

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  private

  def create_activity(kind:, started_at: Time.zone.parse("2026-10-07 12:00:00"))
    Activity.create!(kind:, started_at:)
  end

  def activity_payload(id: nil)
    {
      activity: {
        id:,
        kind: "basketball",
        started_at: "2026-10-07T18:00:00Z",
        ended_at: "2026-10-07T19:12:00Z",
        notes: "Pickup game",
        focus_tags: [ "Lower Body", "Cardio" ]
      }.compact
    }
  end
end
