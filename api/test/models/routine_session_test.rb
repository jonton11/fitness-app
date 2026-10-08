require "test_helper"

class RoutineSessionTest < ActiveSupport::TestCase
  test "requires completion timestamp to match status" do
    active_session = RoutineSession.new(routine_name: "Daily Rehab", status: "active", started_at: Time.current, completed_at: Time.current)
    completed_session = RoutineSession.new(routine_name: "Daily Rehab", status: "completed", started_at: Time.current)

    assert_not active_session.valid?
    assert_includes active_session.errors[:completed_at], "must be blank while the routine is active"
    assert_not completed_session.valid?
    assert_includes completed_session.errors[:completed_at], "can't be blank"
  end

  test "validates routine session item snapshot" do
    item = RoutineSessionItem.new(
      routine_session: RoutineSession.new(routine_name: "Daily Rehab", started_at: Time.current),
      position: 0,
      exercise_name: " ",
      target_mode: "distance",
      sets: 0,
      target_reps: 0,
      target_duration_seconds: 0
    )

    assert_not item.valid?
    assert_includes item.errors[:position], "must be greater than 0"
    assert_includes item.errors[:exercise_name], "can't be blank"
    assert_includes item.errors[:target_mode], "is not included in the list"
    assert_includes item.errors[:sets], "must be greater than 0"
    assert_includes item.errors[:target_reps], "must be greater than 0"
    assert_includes item.errors[:target_duration_seconds], "must be greater than 0"
  end
end
