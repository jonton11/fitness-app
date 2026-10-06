require "test_helper"

class WorkoutTemplateExerciseOptionsApiTest < ActionDispatch::IntegrationTest
  test "adds an exercise option and safely replays the same request" do
    slot = create_slot

    assert_difference -> { WorkoutTemplateExerciseOption.count }, 1 do
      post "/api/v1/workout_template_exercise_options", params: option_params(slot:)
    end

    assert_response :created
    body = response.parsed_body.fetch("workout_template_exercise_option")
    assert_equal smith_press.id, body.fetch("exercise_id")
    assert_equal "Incline Smith Press", body.dig("exercise", "name")
    assert_equal 2, body.fetch("position")
    assert_equal 80.0, body.fetch("starting_load_value")
    assert_equal 10.0, body.fetch("progression_increment")
    assert_equal 1, slot.reload.lock_version

    assert_no_difference -> { WorkoutTemplateExerciseOption.count } do
      post "/api/v1/workout_template_exercise_options", params: option_params(slot:)
    end

    assert_response :success
    assert_equal body.fetch("id"), response.parsed_body.dig("workout_template_exercise_option", "id")
    assert_equal 1, slot.reload.lock_version
  end

  test "does not add an archived exercise option" do
    slot = create_slot
    smith_press.update!(archived_at: Time.current)

    post "/api/v1/workout_template_exercise_options", params: option_params(slot:)

    assert_response :not_found
    assert_equal "exercise_id", response.parsed_body.dig("errors", 0, "field")
    assert_equal 1, slot.exercise_options.count
  end

  test "creates a new exercise and option in one request" do
    slot = create_slot

    assert_difference -> { Exercise.count }, 1 do
      assert_difference -> { WorkoutTemplateExerciseOption.count }, 1 do
        post "/api/v1/workout_template_exercise_options", params: {
          workout_template_exercise_option: {
            workout_template_slot_id: slot.id,
            starting_load_value: 75,
            progression_increment: 5,
            exercise: {
              name: "Incline Machine Press",
              primary_muscle_group: "Chest",
              secondary_muscle_groups: [ "Shoulders", "Triceps" ],
              load_type: "machine_stack",
              notes: "Alternative when dumbbells are occupied."
            }
          }
        }
      end
    end

    assert_response :created
    body = response.parsed_body.fetch("workout_template_exercise_option")
    exercise = Exercise.find(body.fetch("exercise_id"))
    assert_equal "Incline Machine Press", exercise.name
    assert_equal [ "Shoulders", "Triceps" ], exercise.secondary_muscle_groups
    assert_equal "machine_stack", body.dig("exercise", "load_type")
    assert_equal 75.0, body.fetch("starting_load_value")
    assert_equal 5.0, body.fetch("progression_increment")
  end

  private

  def option_params(slot:)
    {
      workout_template_exercise_option: {
        workout_template_slot_id: slot.id,
        exercise_id: smith_press.id,
        starting_load_value: 80,
        progression_increment: 10
      }
    }
  end

  def create_slot
    template = WorkoutTemplate.create!(name: "Upper Body")
    template.slots.create!(
      position: 1,
      label: "Upper Chest Press",
      default_exercise: incline_press,
      rest_seconds: 180
    ).tap do |slot|
      slot.exercise_options.create!(
        position: 1,
        exercise: incline_press,
        is_default: true,
        starting_load_value: 60,
        progression_increment: 5
      )
    end
  end

  def incline_press
    @incline_press ||= Exercise.create!(
      name: "Incline Dumbbell Press",
      primary_muscle_group: "Chest",
      load_type: "lb"
    )
  end

  def smith_press
    @smith_press ||= Exercise.create!(
      name: "Incline Smith Press",
      primary_muscle_group: "Chest",
      load_type: "lb"
    )
  end
end
