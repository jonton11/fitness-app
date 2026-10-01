require "test_helper"

class ExercisesApiTest < ActionDispatch::IntegrationTest
  test "lists exercises with pagination metadata" do
    create_exercise(name: "Cable Lateral Raise", primary_muscle_group: "Shoulders", load_type: "machine_stack")
    create_exercise(name: "Dead Bug", primary_muscle_group: "Core", load_type: "none")

    get "/api/v1/exercises"

    assert_response :success
    body = response.parsed_body
    assert_equal [ "Cable Lateral Raise", "Dead Bug" ], body.fetch("exercises").map { |exercise| exercise.fetch("name") }
    assert_equal({ "limit" => 50, "offset" => 0, "total" => 2 }, body.fetch("meta"))
  end

  test "hides archived exercises by default" do
    create_exercise(name: "Active Exercise", primary_muscle_group: "Chest", load_type: "lb")
    create_exercise(
      name: "Archived Exercise",
      primary_muscle_group: "Back",
      load_type: "kg",
      archived_at: Time.current
    )

    get "/api/v1/exercises"

    assert_response :success
    assert_equal [ "Active Exercise" ], response.parsed_body.fetch("exercises").map { |exercise| exercise.fetch("name") }
  end

  test "lists archived exercises" do
    create_exercise(name: "Active Exercise", primary_muscle_group: "Chest", load_type: "lb")
    create_exercise(
      name: "Archived Exercise",
      primary_muscle_group: "Back",
      load_type: "kg",
      archived_at: Time.current
    )

    get "/api/v1/exercises", params: { status: "archived" }

    assert_response :success
    assert_equal [ "Archived Exercise" ], response.parsed_body.fetch("exercises").map { |exercise| exercise.fetch("name") }
  end

  test "lists all exercises" do
    create_exercise(name: "Active Exercise", primary_muscle_group: "Chest", load_type: "lb")
    create_exercise(
      name: "Archived Exercise",
      primary_muscle_group: "Back",
      load_type: "kg",
      archived_at: Time.current
    )

    get "/api/v1/exercises", params: { status: "all" }

    assert_response :success
    assert_equal [ "Active Exercise", "Archived Exercise" ], response.parsed_body.fetch("exercises").map { |exercise| exercise.fetch("name") }
  end

  test "searches exercises by name and primary muscle group" do
    create_exercise(name: "Cable Lateral Raise", primary_muscle_group: "Shoulders", load_type: "machine_stack")
    create_exercise(name: "Dead Bug", primary_muscle_group: "Core", load_type: "none")

    get "/api/v1/exercises", params: { q: "core" }

    assert_response :success
    body = response.parsed_body
    assert_equal [ "Dead Bug" ], body.fetch("exercises").map { |exercise| exercise.fetch("name") }
    assert_equal 1, body.dig("meta", "total")
  end

  test "creates exercise" do
    assert_difference -> { Exercise.count }, 1 do
      post "/api/v1/exercises", params: {
        exercise: {
          name: "Incline Dumbbell Press",
          primary_muscle_group: "Chest",
          secondary_muscle_groups: [ "Shoulders", "Triceps" ],
          load_type: "lb",
          notes: "Bench setting notch 4",
          external_url: "https://example.com/incline-press"
        }
      }
    end

    assert_response :created
    exercise = response.parsed_body.fetch("exercise")
    assert_equal "Incline Dumbbell Press", exercise.fetch("name")
    assert_equal "Chest", exercise.fetch("primary_muscle_group")
    assert_equal [ "Shoulders", "Triceps" ], exercise.fetch("secondary_muscle_groups")
    assert_equal "lb", exercise.fetch("load_type")
    assert_nil exercise.fetch("archived_at")
    assert_equal 0, exercise.fetch("lock_version")
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, exercise.fetch("created_at"))
  end

  test "shows exercise" do
    exercise = create_exercise(name: "Jefferson Curl", primary_muscle_group: "Back", load_type: "bodyweight")

    get "/api/v1/exercises/#{exercise.id}"

    assert_response :success
    assert_equal "Jefferson Curl", response.parsed_body.dig("exercise", "name")
  end

  test "updates exercise with lock version" do
    exercise = create_exercise(name: "Jefferson Curl", primary_muscle_group: "Back", load_type: "bodyweight")

    patch "/api/v1/exercises/#{exercise.id}", params: {
      exercise: {
        name: "Jefferson Curls",
        primary_muscle_group: "Posterior Chain",
        load_type: "bodyweight",
        lock_version: exercise.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("exercise")
    assert_equal "Jefferson Curls", body.fetch("name")
    assert_equal "Posterior Chain", body.fetch("primary_muscle_group")
    assert_equal 1, body.fetch("lock_version")
  end

  test "archives exercise through update" do
    exercise = create_exercise(name: "Incline Machine Press", primary_muscle_group: "Chest", load_type: "machine_stack")

    patch "/api/v1/exercises/#{exercise.id}", params: {
      exercise: {
        archived_at: Time.current.iso8601,
        lock_version: exercise.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("exercise")
    assert_not_nil body.fetch("archived_at")
    assert_predicate exercise.reload, :archived_at?
  end

  test "restores exercise through update" do
    exercise = create_exercise(
      name: "Incline Machine Press",
      primary_muscle_group: "Chest",
      load_type: "machine_stack",
      archived_at: Time.current
    )

    patch "/api/v1/exercises/#{exercise.id}", params: {
      exercise: {
        archived_at: nil,
        lock_version: exercise.lock_version
      }
    }

    assert_response :success
    body = response.parsed_body.fetch("exercise")
    assert_nil body.fetch("archived_at")
    assert_nil exercise.reload.archived_at
  end

  test "returns validation errors" do
    post "/api/v1/exercises", params: {
      exercise: {
        name: "",
        primary_muscle_group: "",
        load_type: "stack"
      }
    }

    assert_response :unprocessable_content
    errors = response.parsed_body.fetch("errors")
    assert_includes errors, {
      "field" => "name",
      "code" => "blank",
      "message" => "Name can't be blank"
    }
    assert_includes errors, {
      "field" => "load_type",
      "code" => "inclusion",
      "message" => "Load type is not included in the list"
    }
  end

  test "returns not found for missing exercise" do
    get "/api/v1/exercises/00000000-0000-0000-0000-000000000000"

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  test "returns conflict for stale updates" do
    exercise = create_exercise(name: "Dead Bug", primary_muscle_group: "Core", load_type: "none")
    exercise.update!(notes: "First edit")

    patch "/api/v1/exercises/#{exercise.id}", params: {
      exercise: {
        notes: "Stale edit",
        lock_version: 0
      }
    }

    assert_response :conflict
    assert_equal "stale", response.parsed_body.dig("errors", 0, "code")
  end

  private

  def create_exercise(attributes)
    Exercise.create!(attributes)
  end
end
