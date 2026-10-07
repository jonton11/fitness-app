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

  test "creates an idempotent workout session from an offline client snapshot" do
    template = create_template
    slot = template.slots.first
    option = slot.exercise_options.first
    warmup, working = slot.set_prescriptions.to_a
    session_id = SecureRandom.uuid
    session_exercise_id = SecureRandom.uuid
    warmup_set_id = SecureRandom.uuid
    working_set_id = SecureRandom.uuid
    payload = {
      workout_session: {
        id: session_id,
        workout_template_id: template.id,
        workout_template_name: "Cached Upper Body",
        started_at: "2026-10-02T12:00:00Z",
        exercises: [
          {
            id: session_exercise_id,
            workout_template_slot_id: slot.id,
            workout_template_exercise_option_id: option.id,
            selected_exercise_id: incline_press.id,
            position: 1,
            label: "Cached Upper Chest Press",
            selected_exercise_name: "Cached Incline Dumbbell Press",
            selected_exercise_load_type: "lb",
            rest_seconds: 150,
            planned_working_load_value: 62.5,
            progression_increment: 2.5,
            workout_session_sets: [
              {
                id: warmup_set_id,
                workout_template_set_prescription_id: warmup.id,
                position: 1,
                set_type: "warmup",
                target_rep_min: 4,
                target_rep_max: 6,
                load_strategy: "percentage_of_working_load",
                prescribed_load_value: 50,
                planned_load_value: 31.25
              },
              {
                id: working_set_id,
                workout_template_set_prescription_id: working.id,
                position: 2,
                set_type: "working",
                target_rep_min: 5,
                target_rep_max: 8,
                load_strategy: "working_load",
                prescribed_load_value: nil,
                planned_load_value: 62.5
              }
            ]
          }
        ]
      }
    }

    template.update!(name: "Renamed after download", archived_at: Time.current)
    slot.update!(label: "Changed after download", rest_seconds: 90)

    assert_difference -> { WorkoutSession.count }, 1 do
      assert_difference -> { WorkoutSessionExercise.count }, 1 do
        assert_difference -> { WorkoutSessionSet.count }, 2 do
          post "/api/v1/workout_sessions", params: payload
        end
      end
    end

    assert_response :created
    session = response.parsed_body.fetch("workout_session")
    assert_equal session_id, session.fetch("id")
    assert_equal "Cached Upper Body", session.fetch("workout_template_name")
    assert_equal "Cached Upper Chest Press", session.dig("exercises", 0, "label")
    assert_equal "Cached Incline Dumbbell Press", session.dig("exercises", 0, "selected_exercise", "name")
    assert_equal 150, session.dig("exercises", 0, "rest_seconds")
    assert_equal [ warmup_set_id, working_set_id ], session.dig("exercises", 0, "workout_session_sets").map { |set| set.fetch("id") }

    assert_no_difference [
      -> { WorkoutSession.count },
      -> { WorkoutSessionExercise.count },
      -> { WorkoutSessionSet.count }
    ] do
      post "/api/v1/workout_sessions", params: payload
    end

    assert_response :success
    assert_equal session, response.parsed_body.fetch("workout_session")
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

  test "lists completed workout session history newest first" do
    older_session = WorkoutSessions::Start.call(
      workout_template: create_template,
      started_at: Time.zone.parse("2026-10-01 12:00:00")
    )
    newer_session = WorkoutSessions::Start.call(
      workout_template: create_template,
      started_at: Time.zone.parse("2026-10-03 12:00:00")
    )
    WorkoutSessions::Start.call(
      workout_template: create_template,
      started_at: Time.zone.parse("2026-10-04 12:00:00")
    )

    older_session.update!(status: "completed", completed_at: Time.zone.parse("2026-10-01 13:00:00"))
    newer_session.update!(status: "completed", completed_at: Time.zone.parse("2026-10-03 13:00:00"))

    get "/api/v1/workout_sessions"

    assert_response :success
    body = response.parsed_body
    sessions = body.fetch("workout_sessions")
    assert_equal [ newer_session.id, older_session.id ], sessions.map { |session| session.fetch("id") }
    assert_equal "completed", sessions.first.fetch("status")
    assert_equal "Upper Chest Press", sessions.first.dig("exercises", 0, "label")
    assert_equal(
      {
        "limit" => 50,
        "offset" => 0,
        "total" => 2
      },
      body.fetch("meta")
    )
  end

  test "lists active workout sessions when requested" do
    active_session = WorkoutSessions::Start.call(workout_template: create_template)
    completed_session = WorkoutSessions::Start.call(workout_template: create_template)
    completed_session.update!(status: "completed", completed_at: Time.current)

    get "/api/v1/workout_sessions", params: { status: "active" }

    assert_response :success
    sessions = response.parsed_body.fetch("workout_sessions")
    assert_equal [ active_session.id ], sessions.map { |session| session.fetch("id") }
  end

  test "completes workout session and marks pending sets not performed" do
    session = WorkoutSessions::Start.call(workout_template: create_template)
    warmup, working = session.exercises.first.workout_session_sets.to_a
    warmup.update!(
      actual_reps: 5,
      actual_load_value: 30,
      completion_state: "completed",
      completed_at: Time.zone.parse("2026-10-02 11:45:00")
    )

    patch "/api/v1/workout_sessions/#{session.id}", params: {
      workout_session: {
        status: "completed",
        completed_at: "2026-10-02T12:00:00Z",
        lock_version: session.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("workout_session")
    assert_equal "completed", body.fetch("status")
    assert_equal "2026-10-02T12:00:00.000Z", body.fetch("completed_at")
    assert_equal 1, body.fetch("lock_version")

    returned_warmup, returned_working = body.dig("exercises", 0, "workout_session_sets")
    assert_equal "completed", returned_warmup.fetch("completion_state")
    assert_equal 5, returned_warmup.fetch("actual_reps")
    assert_equal "not_performed", returned_working.fetch("completion_state")
    assert_nil returned_working.fetch("actual_reps")
    assert_nil returned_working.fetch("actual_load_value")
    assert_nil returned_working.fetch("completed_at")
    assert_equal "completed", body.dig("exercises", 0, "status")

    assert_equal "not_performed", working.reload.completion_state
  end

  test "cancels workout session without changing set results" do
    session = WorkoutSessions::Start.call(workout_template: create_template)
    first_set = session.exercises.first.workout_session_sets.first
    first_set.update!(
      actual_reps: 5,
      actual_load_value: 30,
      completion_state: "completed",
      completed_at: Time.zone.parse("2026-10-02 11:45:00")
    )

    patch "/api/v1/workout_sessions/#{session.id}", params: {
      workout_session: {
        status: "canceled",
        canceled_at: "2026-10-02T12:00:00Z",
        lock_version: session.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("workout_session")
    assert_equal "canceled", body.fetch("status")
    assert_equal "2026-10-02T12:00:00.000Z", body.fetch("canceled_at")
    assert_nil body.fetch("completed_at")
    assert_equal "completed", body.dig("exercises", 0, "workout_session_sets", 0, "completion_state")
    assert_equal "pending", body.dig("exercises", 0, "workout_session_sets", 1, "completion_state")
  end

  test "does not cancel completed workout history" do
    session = WorkoutSessions::Start.call(workout_template: create_template)
    session.update!(status: "completed", completed_at: Time.zone.parse("2026-10-02 12:00:00"))

    patch "/api/v1/workout_sessions/#{session.id}", params: {
      workout_session: {
        status: "canceled",
        canceled_at: "2026-10-02T13:00:00Z",
        lock_version: session.lock_version
      }
    }

    assert_response :unprocessable_content
    assert_equal "status", response.parsed_body.dig("errors", 0, "field")
    assert_equal "Status must be active", response.parsed_body.dig("errors", 0, "message")
    assert_equal "completed", session.reload.status
    assert_equal Time.zone.parse("2026-10-02 12:00:00"), session.completed_at
  end

  test "returns validation error for invalid canceled at timestamp" do
    session = WorkoutSessions::Start.call(workout_template: create_template)

    patch "/api/v1/workout_sessions/#{session.id}", params: {
      workout_session: {
        status: "canceled",
        canceled_at: "Friday-ish",
        lock_version: session.lock_version
      }
    }

    assert_response :unprocessable_content
    assert_equal(
      {
        "field" => "canceled_at",
        "code" => "invalid",
        "message" => "Canceled at must be an ISO-8601 timestamp"
      },
      response.parsed_body.fetch("errors").first
    )
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

  test "returns conflict when completing a stale workout session" do
    session = WorkoutSessions::Start.call(workout_template: create_template)
    stale_lock_version = session.lock_version
    session.update!(workout_template_name: "Changed")

    patch "/api/v1/workout_sessions/#{session.id}", params: {
      workout_session: {
        status: "completed",
        lock_version: stale_lock_version
      }
    }

    assert_response :conflict
    assert_equal "lock_version", response.parsed_body.dig("errors", 0, "field")
    assert_equal "stale", response.parsed_body.dig("errors", 0, "code")
  end

  test "returns validation error for invalid completed at timestamp" do
    session = WorkoutSessions::Start.call(workout_template: create_template)

    patch "/api/v1/workout_sessions/#{session.id}", params: {
      workout_session: {
        status: "completed",
        completed_at: "Friday-ish",
        lock_version: session.lock_version
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
