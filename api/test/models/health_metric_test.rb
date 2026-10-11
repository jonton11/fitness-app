require "test_helper"

class HealthMetricTest < ActiveSupport::TestCase
  test "requires the canonical unit for each metric kind" do
    metric = build_health_metric(kind: "body_weight", unit: "lb")

    assert_not metric.valid?
    assert_equal [ "must be kg for body weight" ], metric.errors[:unit]
  end

  test "database enforces the canonical unit for each metric kind" do
    metric = build_health_metric
    metric.save!

    error = assert_raises(ActiveRecord::StatementInvalid) do
      HealthMetric.transaction(requires_new: true) do
        HealthMetric.where(id: metric.id).update_all(unit: "kg")
      end
    end

    assert_match "health_metrics_kind_unit_valid", error.message
  end

  test "requires the sample to end after it starts" do
    metric = build_health_metric(
      started_at: Time.zone.parse("2026-10-10 09:00:00"),
      ended_at: Time.zone.parse("2026-10-10 08:59:00")
    )

    assert_not metric.valid?
    assert_equal [ "must be at or after the start time" ], metric.errors[:ended_at]
  end

  private

  def build_health_metric(**attributes)
    HealthMetric.new({
      id: SecureRandom.uuid,
      user: users(:primary),
      kind: "steps",
      value: 1_250,
      unit: "count",
      started_at: Time.zone.parse("2026-10-10 08:00:00"),
      ended_at: Time.zone.parse("2026-10-10 09:00:00")
    }.merge(attributes))
  end
end
