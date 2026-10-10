require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  test "normalizes optional text and focus tags" do
    activity = Activity.create!(
      kind: " basketball ",
      started_at: Time.zone.parse("2026-10-07 18:00:00"),
      notes: "  Pickup game  ",
      focus_tags: [ " Lower Body ", "", "Lower Body", "Cardio" ]
    )

    assert_equal "basketball", activity.kind
    assert_equal "Pickup game", activity.notes
    assert_equal [ "Lower Body", "Cardio" ], activity.focus_tags
    assert_equal "manual", activity.source
  end

  test "requires a supported kind" do
    activity = Activity.new(kind: "run", started_at: Time.current)

    assert_not activity.valid?
    assert_includes activity.errors[:kind], "is not included in the list"
  end

  test "rejects an end time before the start time" do
    activity = Activity.new(
      kind: "recovery",
      started_at: Time.zone.parse("2026-10-07 18:00:00"),
      ended_at: Time.zone.parse("2026-10-07 17:00:00")
    )

    assert_not activity.valid?
    assert_includes activity.errors[:ended_at], "must be at or after the start time"
  end
end
