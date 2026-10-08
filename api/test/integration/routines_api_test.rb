require "test_helper"

class RoutinesApiTest < ActionDispatch::IntegrationTest
  test "lists active routines with pagination metadata" do
    create_routine(name: "Daily Rehab")
    create_routine(name: "Archived Mobility", archived_at: Time.current)

    get "/api/v1/routines"

    assert_response :success
    body = response.parsed_body
    assert_equal [ "Daily Rehab" ], body.fetch("routines").map { |routine| routine.fetch("name") }
    assert_equal({ "limit" => 50, "offset" => 0, "total" => 1 }, body.fetch("meta"))
  end

  test "filters and searches routines" do
    create_routine(name: "Daily Rehab")
    create_routine(name: "Archived Mobility", archived_at: Time.current)

    get "/api/v1/routines", params: { status: "all", q: "mobility" }

    assert_response :success
    assert_equal [ "Archived Mobility" ], response.parsed_body.fetch("routines").map { |routine| routine.fetch("name") }
  end

  test "creates a routine with ordered items" do
    assert_difference -> { Routine.count }, 1 do
      assert_difference -> { RoutineItem.count }, 2 do
        post "/api/v1/routines", params: routine_payload
      end
    end

    assert_response :created
    routine = response.parsed_body.fetch("routine")
    assert_equal "Daily Rehab", routine.fetch("name")
    assert_equal "Move slowly", routine.fetch("notes")
    assert_equal 0, routine.fetch("lock_version")
    assert_equal [ "Hip Rotation", "Dead Bug" ], routine.fetch("items").map { |item| item.dig("exercise", "name") }
    assert_equal [ 1, 2 ], routine.fetch("items").map { |item| item.fetch("position") }
    assert_equal "completion_only", routine.dig("items", 0, "target_mode")
    assert_equal 8, routine.dig("items", 1, "target_reps")
  end

  test "shows a routine" do
    routine = create_routine(name: "Daily Rehab")

    get "/api/v1/routines/#{routine.id}"

    assert_response :success
    assert_equal "Daily Rehab", response.parsed_body.dig("routine", "name")
  end

  test "updates and reorders routine items" do
    routine = create_routine(name: "Daily Rehab")
    first_item, second_item = routine.items.to_a

    patch "/api/v1/routines/#{routine.id}", params: {
      routine: {
        name: "Evening Rehab",
        lock_version: routine.lock_version,
        items: [
          item_payload(second_item.exercise, id: second_item.id, target_mode: "duration", target_duration_seconds: 60),
          item_payload(first_item.exercise, id: first_item.id, target_mode: "completion_only")
        ]
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("routine")
    assert_equal "Evening Rehab", body.fetch("name")
    assert_equal 1, body.fetch("lock_version")
    assert_equal [ second_item.id, first_item.id ], body.fetch("items").map { |item| item.fetch("id") }
    assert_equal [ 1, 2 ], body.fetch("items").map { |item| item.fetch("position") }
  end

  test "partial update preserves routine items" do
    routine = create_routine(name: "Daily Rehab")
    item_ids = routine.items.ids

    patch "/api/v1/routines/#{routine.id}", params: {
      routine: { notes: "Updated", lock_version: routine.lock_version }
    }

    assert_response :success
    assert_equal item_ids, response.parsed_body.dig("routine", "items").map { |item| item.fetch("id") }
  end

  test "archives and restores a routine" do
    routine = create_routine(name: "Daily Rehab")

    patch "/api/v1/routines/#{routine.id}", params: {
      routine: { archived_at: Time.current.iso8601, lock_version: routine.lock_version }
    }

    assert_response :success
    archived = response.parsed_body.fetch("routine")
    assert_not_nil archived.fetch("archived_at")

    patch "/api/v1/routines/#{routine.id}", params: {
      routine: { archived_at: nil, lock_version: archived.fetch("lock_version") }
    }

    assert_response :success
    assert_nil response.parsed_body.dig("routine", "archived_at")
  end

  test "returns validation errors" do
    post "/api/v1/routines", params: { routine: { name: "", items: [] } }

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("errors"), {
      "field" => "name",
      "code" => "blank",
      "message" => "Name can't be blank"
    }
  end

  test "returns nested item validation errors" do
    post "/api/v1/routines", params: {
      routine: {
        name: "Daily Rehab",
        items: [ item_payload(dead_bug, target_mode: "distance") ]
      }
    }

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("errors"), {
      "field" => "target_mode",
      "code" => "inclusion",
      "message" => "Target mode is not included in the list"
    }
  end

  test "returns not found for a missing routine" do
    get "/api/v1/routines/00000000-0000-0000-0000-000000000000"

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  test "returns conflict for a stale routine update" do
    routine = create_routine(name: "Daily Rehab")
    stale_lock_version = routine.lock_version
    routine.update!(notes: "Already changed")

    patch "/api/v1/routines/#{routine.id}", params: {
      routine: { name: "Stale update", lock_version: stale_lock_version }
    }

    assert_response :conflict
    assert_equal "stale", response.parsed_body.dig("errors", 0, "code")
  end

  private

  def routine_payload
    {
      routine: {
        name: "Daily Rehab",
        notes: "Move slowly",
        items: [
          item_payload(hip_rotation, target_mode: "completion_only"),
          item_payload(dead_bug, target_mode: "reps", sets: 3, target_reps: 8, notes_override: "Each side")
        ]
      }
    }
  end

  def create_routine(name:, archived_at: nil)
    routine = Routine.create!(name:, archived_at:)
    routine.items.create!(exercise: hip_rotation, position: 1, target_mode: "completion_only")
    routine.items.create!(exercise: dead_bug, position: 2, target_mode: "reps", sets: 3, target_reps: 8)
    routine
  end

  def item_payload(exercise, **attributes)
    attributes.merge(exercise_id: exercise.id)
  end

  def hip_rotation
    @hip_rotation ||= Exercise.create!(name: "Hip Rotation", primary_muscle_group: "Hips", load_type: "none")
  end

  def dead_bug
    @dead_bug ||= Exercise.create!(name: "Dead Bug", primary_muscle_group: "Core", load_type: "none")
  end
end
