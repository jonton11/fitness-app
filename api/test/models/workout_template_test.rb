require "test_helper"

class WorkoutTemplateTest < ActiveSupport::TestCase
  test "normalizes template fields" do
    template = WorkoutTemplate.new(name: "  Upper Body  ", notes: "  ")

    assert_predicate template, :valid?
    assert_equal "Upper Body", template.name
    assert_nil template.notes
  end

  test "requires a template name" do
    template = WorkoutTemplate.new(name: " ")

    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "validates slot fields" do
    slot = WorkoutTemplateSlot.new(
      workout_template: WorkoutTemplate.new(name: "Upper"),
      default_exercise: exercise,
      position: 0,
      label: " ",
      rest_seconds: -1
    )

    assert_not slot.valid?
    assert_includes slot.errors[:position], "must be greater than 0"
    assert_includes slot.errors[:label], "can't be blank"
    assert_includes slot.errors[:rest_seconds], "must be greater than or equal to 0"
  end

  test "keeps default exercise option aligned with the slot default exercise" do
    slot = WorkoutTemplateSlot.new(
      workout_template: WorkoutTemplate.new(name: "Upper"),
      default_exercise: exercise,
      position: 1,
      label: "Upper Chest Press",
      rest_seconds: 180
    )
    option = WorkoutTemplateExerciseOption.new(
      workout_template_slot: slot,
      exercise: Exercise.new(name: "Incline Smith Press", primary_muscle_group: "Chest", load_type: "lb"),
      position: 1,
      is_default: true
    )

    assert_not option.valid?
    assert_includes option.errors[:exercise_id], "must match the slot default exercise"
  end

  test "validates exercise option load configuration" do
    option = WorkoutTemplateExerciseOption.new(
      workout_template_slot: WorkoutTemplateSlot.new(
        workout_template: WorkoutTemplate.new(name: "Upper"),
        default_exercise: exercise,
        position: 1,
        label: "Upper Chest Press"
      ),
      exercise: exercise,
      position: 1,
      is_default: true,
      starting_load_value: -5,
      next_load_value: -5,
      progression_increment: -2.5
    )

    assert_not option.valid?
    assert_includes option.errors[:starting_load_value], "must be greater than or equal to 0"
    assert_includes option.errors[:next_load_value], "must be greater than or equal to 0"
    assert_includes option.errors[:progression_increment], "must be greater than or equal to 0"
  end

  test "validates set prescription ranges and load strategy value" do
    prescription = WorkoutTemplateSetPrescription.new(
      workout_template_slot: WorkoutTemplateSlot.new(
        workout_template: WorkoutTemplate.new(name: "Upper"),
        default_exercise: exercise,
        position: 1,
        label: "Upper Chest Press"
      ),
      position: 1,
      set_type: "warmup",
      rep_min: 8,
      rep_max: 5,
      load_strategy: "percentage_of_working_load"
    )

    assert_not prescription.valid?
    assert_includes prescription.errors[:rep_max], "must be greater than or equal to rep min"
    assert_includes prescription.errors[:load_value], "can't be blank"
  end

  test "accepts a complete template aggregate" do
    template = WorkoutTemplate.new(name: "Upper", notes: "Main upper day")
    slot = template.slots.build(
      position: 1,
      label: "Upper Chest Press",
      default_exercise: exercise,
      rest_seconds: 180
    )
    slot.exercise_options.build(
      position: 1,
      exercise: exercise,
      is_default: true,
      starting_load_value: 60,
      next_load_value: 65,
      progression_increment: 5
    )
    slot.set_prescriptions.build(
      position: 1,
      set_type: "working",
      rep_min: 5,
      rep_max: 8,
      load_strategy: "working_load"
    )

    assert_predicate template, :valid?
    assert_predicate slot, :valid?
    assert_predicate slot.exercise_options.first, :valid?
    assert_predicate slot.set_prescriptions.first, :valid?
  end

  private

  def exercise
    @exercise ||= Exercise.create!(
      name: "Incline Dumbbell Press",
      primary_muscle_group: "Chest",
      load_type: "lb"
    )
  end
end
