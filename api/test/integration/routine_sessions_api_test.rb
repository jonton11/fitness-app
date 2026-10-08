require "test_helper"

class RoutineSessionsApiTest < ActionDispatch::IntegrationTest
  test "starts a routine session from a client-generated snapshot" do
    routine = create_routine
    session_id = SecureRandom.uuid
    item_ids = routine.items.index_with { SecureRandom.uuid }

    assert_difference -> { RoutineSession.count }, 1 do
      assert_difference -> { RoutineSessionItem.count }, 2 do
        post "/api/v1/routine_sessions", params: start_payload(routine, session_id:, item_ids:)
      end
    end

    assert_response :created
    session = response.parsed_body.fetch("routine_session")
    assert_equal session_id, session.fetch("id")
    assert_equal "Daily Rehab", session.fetch("routine_name")
    assert_equal "active", session.fetch("status")
    assert_equal item_ids.values, session.fetch("items").map { |item| item.fetch("id") }
    assert_equal [ "Hip Rotation", "Dead Bug" ], session.fetch("items").map { |item| item.fetch("exercise_name") }
  end

  test "replaying a routine start does not duplicate history" do
    routine = create_routine
    session_id = SecureRandom.uuid
    payload = start_payload(routine, session_id:)

    post "/api/v1/routine_sessions", params: payload
    assert_response :created

    assert_no_difference [ -> { RoutineSession.count }, -> { RoutineSessionItem.count } ] do
      post "/api/v1/routine_sessions", params: payload
    end

    assert_response :success
    assert_equal session_id, response.parsed_body.dig("routine_session", "id")
  end

  test "does not start an archived routine" do
    routine = create_routine
    routine.update!(archived_at: Time.current)

    post "/api/v1/routine_sessions", params: start_payload(routine)

    assert_response :not_found
    assert_equal "routine_id", response.parsed_body.dig("errors", 0, "field")
  end

  test "updates checklist completion and detects stale writes" do
    session = start_session
    item = session.items.first

    patch "/api/v1/routine_session_items/#{item.id}", params: {
      routine_session_item: {
        completed: true,
        completed_at: "2026-10-07T18:00:00Z",
        lock_version: item.lock_version
      }
    }

    assert_response :success
    completed_item = response.parsed_body.fetch("routine_session_item")
    assert_equal "2026-10-07T18:00:00.000Z", completed_item.fetch("completed_at")
    assert_equal 1, completed_item.fetch("lock_version")

    patch "/api/v1/routine_session_items/#{item.id}", params: {
      routine_session_item: { completed: false, lock_version: item.lock_version }
    }

    assert_response :conflict
    assert_equal "stale", response.parsed_body.dig("errors", 0, "code")
  end

  test "requires checklist completion state" do
    item = start_session.items.first

    patch "/api/v1/routine_session_items/#{item.id}", params: {
      routine_session_item: { lock_version: item.lock_version }
    }

    assert_response :unprocessable_content
    assert_equal "completed", response.parsed_body.dig("errors", 0, "field")
  end

  test "requires every checklist item before completing a routine" do
    session = start_session

    patch "/api/v1/routine_sessions/#{session.id}", params: {
      routine_session: { status: "completed", lock_version: session.lock_version }
    }

    assert_response :unprocessable_content
    assert_equal "Complete every routine item before finishing", response.parsed_body.dig("errors", 0, "message")
  end

  test "completes and lists immutable routine history" do
    session = start_session
    complete_items(session)

    patch "/api/v1/routine_sessions/#{session.id}", params: {
      routine_session: {
        status: "completed",
        completed_at: "2026-10-07T18:15:00Z",
        lock_version: session.lock_version
      }
    }

    assert_response :success
    completed_session = response.parsed_body.fetch("routine_session")
    assert_equal "completed", completed_session.fetch("status")
    assert_equal "2026-10-07T18:15:00.000Z", completed_session.fetch("completed_at")

    session.routine.update!(name: "Changed Routine")
    session.items.first.exercise.update!(name: "Changed Exercise")

    get "/api/v1/routine_sessions"

    assert_response :success
    history = response.parsed_body.fetch("routine_sessions")
    assert_equal [ session.id ], history.map { |entry| entry.fetch("id") }
    assert_equal "Daily Rehab", history.first.fetch("routine_name")
    assert_equal "Hip Rotation", history.first.dig("items", 0, "exercise_name")
    assert_equal({ "limit" => 50, "offset" => 0, "total" => 1 }, response.parsed_body.fetch("meta"))
  end

  test "does not change completed routine history" do
    session = start_session
    complete_items(session)
    session.update!(status: "completed", completed_at: Time.current)
    item = session.items.first.reload

    patch "/api/v1/routine_session_items/#{item.id}", params: {
      routine_session_item: { completed: false, lock_version: item.lock_version }
    }

    assert_response :unprocessable_content
    assert_equal "Completed routine history cannot be changed", response.parsed_body.dig("errors", 0, "message")
    assert_not_nil item.reload.completed_at
  end

  test "rejects invalid timestamps" do
    routine = create_routine

    post "/api/v1/routine_sessions", params: start_payload(routine, started_at: "not-a-time")

    assert_response :unprocessable_content
    assert_equal "started_at", response.parsed_body.dig("errors", 0, "field")
  end

  private

  def create_routine
    routine = Routine.create!(name: "Daily Rehab")
    routine.items.create!(
      exercise: Exercise.create!(name: "Hip Rotation", primary_muscle_group: "Hips", load_type: "none"),
      position: 1,
      target_mode: "completion_only"
    )
    routine.items.create!(
      exercise: Exercise.create!(name: "Dead Bug", primary_muscle_group: "Core", load_type: "none"),
      position: 2,
      target_mode: "reps",
      sets: 3,
      target_reps: 8,
      notes_override: "Each side"
    )
    routine
  end

  def start_session
    routine = create_routine
    RoutineSessions::Start.call(
      routine:,
      attributes: { id: SecureRandom.uuid, started_at: Time.current }
    ).routine_session
  end

  def start_payload(routine, session_id: SecureRandom.uuid, item_ids: {}, started_at: "2026-10-07T17:30:00Z")
    {
      routine_session: {
        id: session_id,
        routine_id: routine.id,
        started_at:,
        items: routine.items.map do |item|
          { id: item_ids[item], routine_item_id: item.id }.compact
        end
      }
    }
  end

  def complete_items(session)
    session.items.each do |item|
      RoutineSessionItems::Update.call(
        routine_session_item: item,
        attributes: { completed: true, lock_version: item.lock_version }
      )
    end
  end
end
