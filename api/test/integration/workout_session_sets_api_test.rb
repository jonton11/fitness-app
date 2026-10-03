require "test_helper"

class WorkoutSessionSetsApiTest < ActionDispatch::IntegrationTest
  test "updates workout session set with actual reps and defaults load to planned load" do
    workout_session_set = create_workout_session_set(planned_load_value: 65)

    patch "/api/v1/workout_session_sets/#{workout_session_set.id}", params: {
      workout_session_set: {
        actual_reps: 7,
        completed_at: "2026-10-02T12:00:00Z",
        lock_version: workout_session_set.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("workout_session_set")
    assert_equal workout_session_set.id, body.fetch("id")
    assert_equal "completed", body.fetch("completion_state")
    assert_equal 7, body.fetch("actual_reps")
    assert_equal 65.0, body.fetch("actual_load_value")
    assert_equal "2026-10-02T12:00:00.000Z", body.fetch("completed_at")
    assert_equal 1, body.fetch("lock_version")
  end

  test "preserves omitted actual fields when updating performed workout session set" do
    completed_at = Time.zone.parse("2026-10-02 11:30:00")
    workout_session_set = create_workout_session_set(
      completion_state: "completed",
      actual_reps: 7,
      actual_load_value: 62.5,
      completed_at:
    )

    patch "/api/v1/workout_session_sets/#{workout_session_set.id}", params: {
      workout_session_set: {
        actual_reps: 8,
        lock_version: workout_session_set.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("workout_session_set")
    assert_equal "completed", body.fetch("completion_state")
    assert_equal 8, body.fetch("actual_reps")
    assert_equal 62.5, body.fetch("actual_load_value")
    assert_equal "2026-10-02T11:30:00.000Z", body.fetch("completed_at")
    assert_equal 1, body.fetch("lock_version")
  end

  test "updates workout session set with explicit attempted state and load" do
    workout_session_set = create_workout_session_set(planned_load_value: 65)

    patch "/api/v1/workout_session_sets/#{workout_session_set.id}", params: {
      workout_session_set: {
        completion_state: "attempted_but_target_not_met",
        actual_reps: 3,
        actual_load_value: 60,
        completed_at: "2026-10-02T12:00:00Z",
        lock_version: workout_session_set.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("workout_session_set")
    assert_equal "attempted_but_target_not_met", body.fetch("completion_state")
    assert_equal 3, body.fetch("actual_reps")
    assert_equal 60.0, body.fetch("actual_load_value")
  end

  test "marks workout session set not performed and clears actuals" do
    workout_session_set = create_workout_session_set(
      completion_state: "completed",
      actual_reps: 7,
      actual_load_value: 65,
      completed_at: Time.current
    )

    patch "/api/v1/workout_session_sets/#{workout_session_set.id}", params: {
      workout_session_set: {
        completion_state: "not_performed",
        lock_version: workout_session_set.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("workout_session_set")
    assert_equal "not_performed", body.fetch("completion_state")
    assert_nil body.fetch("actual_reps")
    assert_nil body.fetch("actual_load_value")
    assert_nil body.fetch("completed_at")
  end

  test "returns validation errors when performed set has no reps" do
    workout_session_set = create_workout_session_set

    patch "/api/v1/workout_session_sets/#{workout_session_set.id}", params: {
      workout_session_set: {
        completion_state: "completed",
        completed_at: "2026-10-02T12:00:00Z",
        lock_version: workout_session_set.lock_version
      }
    }

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("errors"), {
      "field" => "actual_reps",
      "code" => "blank",
      "message" => "Actual reps can't be blank"
    }
  end

  test "returns validation error for invalid completed at timestamp" do
    workout_session_set = create_workout_session_set

    patch "/api/v1/workout_session_sets/#{workout_session_set.id}", params: {
      workout_session_set: {
        actual_reps: 7,
        completed_at: "later"
      }
    }

    assert_response :unprocessable_content
    assert_equal(
      {
        "field" => "completed_at",
        "code" => "invalid",
        "message" => "Completed at must be an ISO-8601 timestamp"
      },
      response.parsed_body.fetch("errors").first
    )
  end

  test "returns conflict for stale updates" do
    workout_session_set = create_workout_session_set
    workout_session_set.update!(
      completion_state: "completed",
      actual_reps: 7,
      actual_load_value: 65,
      completed_at: Time.current
    )

    patch "/api/v1/workout_session_sets/#{workout_session_set.id}", params: {
      workout_session_set: {
        actual_reps: 8,
        lock_version: 0
      }
    }

    assert_response :conflict
    assert_equal "lock_version", response.parsed_body.dig("errors", 0, "field")
    assert_equal "stale", response.parsed_body.dig("errors", 0, "code")
  end

  test "returns not found for missing workout session set" do
    patch "/api/v1/workout_session_sets/00000000-0000-0000-0000-000000000000", params: {
      workout_session_set: {
        actual_reps: 7
      }
    }

    assert_response :not_found
    assert_equal "id", response.parsed_body.dig("errors", 0, "field")
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  private

  def create_workout_session_set(attributes = {})
    template = WorkoutTemplate.create!(name: "Upper")
    exercise = Exercise.create!(
      name: "Incline Dumbbell Press",
      primary_muscle_group: "Chest",
      load_type: "lb"
    )
    session = WorkoutSession.create!(
      workout_template: template,
      workout_template_name: template.name,
      started_at: Time.current
    )
    session_exercise = session.exercises.create!(
      selected_exercise: exercise,
      position: 1,
      label: "Upper Chest Press",
      selected_exercise_name: exercise.name,
      selected_exercise_load_type: exercise.load_type,
      rest_seconds: 180
    )
    session_exercise.workout_session_sets.create!(
      {
        position: 1,
        set_type: "working",
        target_rep_min: 5,
        target_rep_max: 8,
        load_strategy: "working_load",
        planned_load_value: 65
      }.merge(attributes)
    )
  end
end
