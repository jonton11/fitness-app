require "test_helper"

class RoutineTest < ActiveSupport::TestCase
  test "normalizes routine fields and orders items" do
    routine = Routine.create!(name: "  Daily Rehab  ", notes: "  ")
    routine.items.create!(exercise: exercise("Dead Bug"), position: 2, target_mode: "reps", target_reps: 8)
    routine.items.create!(exercise: exercise("Hip Rotation"), position: 1, target_mode: "completion_only")

    assert_equal "Daily Rehab", routine.name
    assert_nil routine.notes
    assert_equal [ "Hip Rotation", "Dead Bug" ], routine.items.reload.map { |item| item.exercise.name }
  end

  test "requires a routine name" do
    routine = Routine.new(name: " ")

    assert_not routine.valid?
    assert_includes routine.errors[:name], "can't be blank"
  end

  test "validates routine item targets" do
    item = RoutineItem.new(
      routine: Routine.new(name: "Daily Rehab"),
      exercise: exercise("Dead Bug"),
      position: 0,
      target_mode: "distance",
      sets: 0,
      target_reps: 0,
      target_duration_seconds: 0
    )

    assert_not item.valid?
    assert_includes item.errors[:position], "must be greater than 0"
    assert_includes item.errors[:target_mode], "is not included in the list"
    assert_includes item.errors[:sets], "must be greater than 0"
    assert_includes item.errors[:target_reps], "must be greater than 0"
    assert_includes item.errors[:target_duration_seconds], "must be greater than 0"
  end

  test "accepts each supported target mode" do
    RoutineItem::TARGET_MODES.each_with_index do |target_mode, index|
      item = RoutineItem.new(
        routine: Routine.new(name: "Daily Rehab"),
        exercise: exercise("Exercise #{index}"),
        position: index + 1,
        target_mode:
      )

      assert_predicate item, :valid?
    end
  end

  private

  def exercise(name)
    Exercise.create!(name:, primary_muscle_group: "Core", load_type: "none")
  end
end
