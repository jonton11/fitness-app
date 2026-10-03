require "test_helper"

class WorkoutSessionsApiTest < ActionDispatch::IntegrationTest
  test "creates workout session snapshot from an active template" do
    template = create_template

    assert_difference -> { WorkoutSession.count }, 1 do
      assert_difference -> { WorkoutSessionExercise.count }, 1 do
        assert_difference -> { WorkoutSessionSet.count }, 2 do
          post "/api/v1/workout_sessions", params: {
            workout_session: {
              workout_template_id: template.id,
              started_at: "2026-10-02T12:00:00Z"
            }
          }
        end
      end
    end

    assert_response :created
    session = response.parsed_body.fetch("workout_session")
    assert_equal template.id, session.fetch("workout_template_id")
    assert_equal "Upper Body", session.fetch("workout_template_name")
    assert_equal "active", session.fetch("status")
    assert_equal "2026-10-02T12:00:00.000Z", session.fetch("started_at")
    assert_equal 0, session.fetch("lock_version")

    exercise = session.fetch("exercises").first
    assert_equal "Upper Chest Press", exercise.fetch("label")
    assert_equal incline_press.id, exercise.fetch("selected_exercise_id")
    assert_equal "Incline Dumbbell Press", exercise.dig("selected_exercise", "name")
    assert_equal "lb", exercise.dig("selected_exercise", "load_type")
    assert_equal 180, exercise.fetch("rest_seconds")
    assert_equal 60.0, exercise.fetch("planned_working_load_value")
    assert_equal 5.0, exercise.fetch("progression_increment")
    assert_equal "pending", exercise.fetch("status")

    warmup, working = exercise.fetch("workout_session_sets")
    assert_equal "warmup", warmup.fetch("set_type")
    assert_equal "percentage_of_working_load", warmup.fetch("load_strategy")
    assert_equal 50.0, warmup.fetch("prescribed_load_value")
    assert_equal 30.0, warmup.fetch("planned_load_value")
    assert_equal "pending", warmup.fetch("completion_state")

    assert_equal "working", working.fetch("set_type")
    assert_equal 60.0, working.fetch("planned_load_value")
  end

  test "shows workout session snapshot" do
    session = WorkoutSessions::Start.call(workout_template: create_template)

    get "/api/v1/workout_sessions/#{session.id}"

    assert_response :success
    body = response.parsed_body.fetch("workout_session")
    assert_equal session.id, body.fetch("id")
    assert_equal "Upper Body", body.fetch("workout_template_name")
    assert_equal [ "Upper Chest Press" ], body.fetch("exercises").map { |exercise| exercise.fetch("label") }
  end

  test "keeps returned session snapshot stable after template edits" do
    template = create_template
    session = WorkoutSessions::Start.call(workout_template: template)

    template.update!(name: "Renamed Upper")
    template.slots.first.update!(label: "Changed Slot", rest_seconds: 90)
    template.slots.first.exercise_options.first.update!(starting_load_value: 80, progression_increment: 10)
    template.slots.first.set_prescriptions.first.update!(rep_min: 8, rep_max: 10, load_value: 75)
    incline_press.update!(name: "Renamed Press", load_type: "kg")

    get "/api/v1/workout_sessions/#{session.id}"

    assert_response :success
    body = response.parsed_body.fetch("workout_session")
    exercise = body.fetch("exercises").first
    warmup = exercise.fetch("workout_session_sets").first

    assert_equal "Upper Body", body.fetch("workout_template_name")
    assert_equal "Upper Chest Press", exercise.fetch("label")
    assert_equal 180, exercise.fetch("rest_seconds")
    assert_equal 60.0, exercise.fetch("planned_working_load_value")
    assert_equal 5.0, exercise.fetch("progression_increment")
    assert_equal "Incline Dumbbell Press", exercise.dig("selected_exercise", "name")
    assert_equal "lb", exercise.dig("selected_exercise", "load_type")
    assert_equal 4, warmup.fetch("target_rep_min")
    assert_equal 6, warmup.fetch("target_rep_max")
    assert_equal 50.0, warmup.fetch("prescribed_load_value")
  end

  test "does not start archived workout template" do
    template = create_template
    template.update!(archived_at: Time.current)

    post "/api/v1/workout_sessions", params: {
      workout_session: {
        workout_template_id: template.id
      }
    }

    assert_response :not_found
    assert_equal "workout_template_id", response.parsed_body.dig("errors", 0, "field")
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  test "returns not found for missing workout template" do
    post "/api/v1/workout_sessions", params: {
      workout_session: {
        workout_template_id: "00000000-0000-0000-0000-000000000000"
      }
    }

    assert_response :not_found
    assert_equal "workout_template_id", response.parsed_body.dig("errors", 0, "field")
    assert_equal "Workout template not found", response.parsed_body.dig("errors", 0, "message")
  end

  test "returns not found for missing workout session" do
    get "/api/v1/workout_sessions/00000000-0000-0000-0000-000000000000"

    assert_response :not_found
    assert_equal "id", response.parsed_body.dig("errors", 0, "field")
    assert_equal "Workout session not found", response.parsed_body.dig("errors", 0, "message")
  end

  test "returns validation error for invalid started at timestamp" do
    post "/api/v1/workout_sessions", params: {
      workout_session: {
        workout_template_id: create_template.id,
        started_at: "Friday-ish"
      }
    }

    assert_response :unprocessable_content
    assert_equal(
      {
        "field" => "started_at",
        "code" => "invalid",
        "message" => "Started at must be an ISO-8601 timestamp"
      },
      response.parsed_body.fetch("errors").first
    )
  end

  private

  def create_template
    template = WorkoutTemplate.create!(name: "Upper Body")
    slot = template.slots.create!(
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
      next_load_value: 65,
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
    template
  end

  def incline_press
    @incline_press ||= Exercise.create!(
      name: "Incline Dumbbell Press",
      primary_muscle_group: "Chest",
      load_type: "lb"
    )
  end
end
