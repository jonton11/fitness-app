require "test_helper"

class ExerciseTest < ActiveSupport::TestCase
  test "valid exercise" do
    exercise = Exercise.new(
      name: "Incline Dumbbell Press",
      primary_muscle_group: "Chest",
      secondary_muscle_groups: [ "Shoulders", "Triceps" ],
      load_type: "lb",
      notes: "Bench setting notch 4",
      external_url: "https://example.com/incline-press"
    )

    assert exercise.valid?
  end

  test "requires core fields" do
    exercise = Exercise.new

    assert_not exercise.valid?
    assert_includes exercise.errors[:name], "can't be blank"
    assert_includes exercise.errors[:primary_muscle_group], "can't be blank"
    assert_includes exercise.errors[:load_type], "can't be blank"
  end

  test "requires supported load type" do
    exercise = Exercise.new(
      name: "Cable Lateral Raise",
      primary_muscle_group: "Shoulders",
      load_type: "stack"
    )

    assert_not exercise.valid?
    assert_includes exercise.errors[:load_type], "is not included in the list"
  end

  test "normalizes whitespace and empty secondary muscle groups" do
    exercise = Exercise.new(
      name: " Jefferson Curl ",
      primary_muscle_group: " Back ",
      secondary_muscle_groups: [ "Hamstrings", "", "  " ],
      load_type: " bodyweight "
    )

    assert exercise.valid?
    assert_equal "Jefferson Curl", exercise.name
    assert_equal "Back", exercise.primary_muscle_group
    assert_equal [ "Hamstrings" ], exercise.secondary_muscle_groups
    assert_equal "bodyweight", exercise.load_type
  end

  test "requires http or https external URL when present" do
    exercise = Exercise.new(
      name: "Dead Bug",
      primary_muscle_group: "Core",
      load_type: "none",
      external_url: "not a url"
    )

    assert_not exercise.valid?
    assert_includes exercise.errors[:external_url], "is invalid"
  end
end
