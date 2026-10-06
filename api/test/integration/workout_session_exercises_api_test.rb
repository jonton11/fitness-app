require "test_helper"

class WorkoutSessionExercisesApiTest < ActionDispatch::IntegrationTest
  test "substitutes a pending session exercise and recalculates planned loads" do
    session_exercise = start_session.exercises.first
    warmup, working = session_exercise.workout_session_sets.to_a

    patch "/api/v1/workout_session_exercises/#{session_exercise.id}", params: {
      workout_session_exercise: {
        workout_template_exercise_option_id: substitute_option.id,
        lock_version: session_exercise.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("workout_session_exercise")
    assert_equal substitute_option.id, body.fetch("workout_template_exercise_option_id")
    assert_equal smith_press.id, body.fetch("selected_exercise_id")
    assert_equal "Incline Smith Press", body.dig("selected_exercise", "name")
    assert_equal 80.0, body.fetch("planned_working_load_value")
    assert_equal 10.0, body.fetch("progression_increment")
    assert_equal 1, body.fetch("lock_version")
    assert_equal 40.0, body.dig("workout_session_sets", 0, "planned_load_value")
    assert_equal 80.0, body.dig("workout_session_sets", 1, "planned_load_value")
    assert_equal BigDecimal("40"), warmup.reload.planned_load_value
    assert_equal BigDecimal("80"), working.reload.planned_load_value
  end

  test "does not substitute after a set has been performed" do
    session_exercise = start_session.exercises.first
    session_exercise.workout_session_sets.first.update!(
      actual_reps: 6,
      actual_load_value: 30,
      completion_state: "completed",
      completed_at: Time.current
    )

    patch "/api/v1/workout_session_exercises/#{session_exercise.id}", params: {
      workout_session_exercise: {
        workout_template_exercise_option_id: substitute_option.id,
        lock_version: session_exercise.lock_version
      }
    }

    assert_response :unprocessable_content
    assert_equal "workout_session_sets", response.parsed_body.dig("errors", 0, "field")
    assert_equal incline_press.id, session_exercise.reload.selected_exercise_id
  end

  test "does not substitute a completed session" do
    session = start_session
    session.update!(status: "completed", completed_at: Time.current)
    session_exercise = session.exercises.first

    patch "/api/v1/workout_session_exercises/#{session_exercise.id}", params: {
      workout_session_exercise: {
        workout_template_exercise_option_id: substitute_option.id,
        lock_version: session_exercise.lock_version
      }
    }

    assert_response :unprocessable_content
    assert_equal "workout_session", response.parsed_body.dig("errors", 0, "field")
    assert_equal incline_press.id, session_exercise.reload.selected_exercise_id
  end

  test "does not substitute an option from another template slot" do
    session_exercise = start_session.exercises.first
    other_template = create_template(name: "Other Upper")
    other_option = other_template.slots.first.exercise_options.create!(
      position: 2,
      exercise: smith_press,
      progression_increment: 10
    )

    patch "/api/v1/workout_session_exercises/#{session_exercise.id}", params: {
      workout_session_exercise: {
        workout_template_exercise_option_id: other_option.id,
        lock_version: session_exercise.lock_version
      }
    }

    assert_response :unprocessable_content
    assert_equal "workout_template_exercise_option_id", response.parsed_body.dig("errors", 0, "field")
    assert_equal incline_press.id, session_exercise.reload.selected_exercise_id
  end

  test "returns conflict for a stale session exercise" do
    session_exercise = start_session.exercises.first
    stale_lock_version = session_exercise.lock_version
    session_exercise.update!(label: "Changed")

    patch "/api/v1/workout_session_exercises/#{session_exercise.id}", params: {
      workout_session_exercise: {
        workout_template_exercise_option_id: substitute_option.id,
        lock_version: stale_lock_version
      }
    }

    assert_response :conflict
    assert_equal "lock_version", response.parsed_body.dig("errors", 0, "field")
    assert_equal "stale", response.parsed_body.dig("errors", 0, "code")
    assert_equal incline_press.id, session_exercise.reload.selected_exercise_id
  end

  private

  def start_session
    @start_session ||= WorkoutSessions::Start.call(workout_template: template)
  end

  def template
    @template ||= create_template(name: "Upper Body").tap do |workout_template|
      workout_template.slots.first.exercise_options.create!(
        position: 2,
        exercise: smith_press,
        starting_load_value: 80,
        progression_increment: 10
      )
    end
  end

  def substitute_option
    template.slots.first.exercise_options.find_by!(exercise: smith_press)
  end

  def create_template(name:)
    workout_template = WorkoutTemplate.create!(name:)
    slot = workout_template.slots.create!(
      position: 1,
      label: "Upper Chest Press",
      default_exercise: incline_press,
      rest_seconds: 180
    )
    slot.exercise_options.create!(
      position: 1,
      exercise: incline_press,
      is_default: true,
      starting_load_value: 60,
      progression_increment: 5
    )
    slot.set_prescriptions.create!(
      position: 1,
      set_type: "warmup",
      rep_min: 4,
      rep_max: 6,
      load_strategy: "percentage_of_working_load",
      load_value: 50
    )
    slot.set_prescriptions.create!(
      position: 2,
      set_type: "working",
      rep_min: 5,
      rep_max: 8,
      load_strategy: "working_load"
    )
    workout_template
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
