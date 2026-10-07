require "test_helper"

class WorkoutTemplatesApiTest < ActionDispatch::IntegrationTest
  test "lists active workout templates with pagination metadata" do
    create_template(name: "Upper Body")
    create_template(name: "Archived Legs", archived_at: Time.current)

    get "/api/v1/workout_templates"

    assert_response :success
    body = response.parsed_body
    assert_equal [ "Upper Body" ], body.fetch("workout_templates").map { |template| template.fetch("name") }
    assert_equal({ "limit" => 50, "offset" => 0, "total" => 1 }, body.fetch("meta"))
  end

  test "lists planned loads without materializing workout history" do
    template = create_template(name: "Upper Body")
    slot = template.slots.first
    option = slot.exercise_options.first
    session = WorkoutSession.create!(
      workout_template: template,
      workout_template_name: template.name,
      status: "completed",
      started_at: 1.day.ago,
      completed_at: Time.current
    )
    session.exercises.create!(
      workout_template_slot: slot,
      workout_template_exercise_option: option,
      selected_exercise: option.exercise,
      position: 1,
      label: slot.label,
      selected_exercise_name: option.exercise.name,
      selected_exercise_load_type: option.exercise.load_type,
      rest_seconds: slot.rest_seconds,
      status: "completed"
    )

    assert_no_queries_match(/SELECT "workout_session_exercises"\.\*/) do
      assert_queries_match(
        /SELECT DISTINCT .*workout_template_exercise_option_id.*FROM "workout_session_exercises"/,
        count: 1
      ) do
        get "/api/v1/workout_templates"
      end
    end

    assert_response :success
    planned_load = response.parsed_body.dig(
      "workout_templates",
      0,
      "slots",
      0,
      "exercise_options",
      0,
      "planned_working_load_value"
    )
    assert_equal 65.0, planned_load
  end

  test "lists archived workout templates" do
    create_template(name: "Upper Body")
    create_template(name: "Archived Legs", archived_at: Time.current)

    get "/api/v1/workout_templates", params: { status: "archived" }

    assert_response :success
    assert_equal [ "Archived Legs" ], response.parsed_body.fetch("workout_templates").map { |template| template.fetch("name") }
  end

  test "searches workout templates by name" do
    create_template(name: "Upper Body")
    create_template(name: "Legs Strength")

    get "/api/v1/workout_templates", params: { q: "legs" }

    assert_response :success
    assert_equal [ "Legs Strength" ], response.parsed_body.fetch("workout_templates").map { |template| template.fetch("name") }
  end

  test "creates workout template aggregate" do
    assert_difference -> { WorkoutTemplate.count }, 1 do
      assert_difference -> { WorkoutTemplateSlot.count }, 1 do
        assert_difference -> { WorkoutTemplateExerciseOption.count }, 2 do
          assert_difference -> { WorkoutTemplateSetPrescription.count }, 2 do
            assert_no_queries_match(/FROM "workout_session_exercises"/) do
              post "/api/v1/workout_templates", params: template_payload
            end
          end
        end
      end
    end

    assert_response :created
    template = response.parsed_body.fetch("workout_template")
    assert_equal "Upper Body", template.fetch("name")
    assert_equal "Main push/pull upper body day.", template.fetch("notes")
    assert_equal 0, template.fetch("lock_version")

    slot = template.fetch("slots").first
    assert_equal "Upper Chest Press", slot.fetch("label")
    assert_equal incline_press.id, slot.fetch("default_exercise_id")
    assert_equal "Incline Dumbbell Press", slot.dig("default_exercise", "name")
    assert_equal 180, slot.fetch("rest_seconds")

    default_option = slot.fetch("exercise_options").first
    assert_equal incline_press.id, default_option.fetch("exercise_id")
    assert_equal true, default_option.fetch("is_default")
    assert_equal 60.0, default_option.fetch("starting_load_value")
    assert_equal 65.0, default_option.fetch("next_load_value")
    assert_nil default_option.fetch("calculated_next_load_value")
    assert_equal 5.0, default_option.fetch("progression_increment")
    assert_equal 60.0, default_option.fetch("planned_working_load_value")
    assert_equal(
      [
        {
          "workout_template_set_prescription_id" => slot.fetch("set_prescriptions").first.fetch("id"),
          "planned_load_value" => 39.0
        },
        {
          "workout_template_set_prescription_id" => slot.fetch("set_prescriptions").second.fetch("id"),
          "planned_load_value" => 60.0
        }
      ],
      default_option.fetch("planned_session_sets")
    )

    warmup = slot.fetch("set_prescriptions").first
    assert_equal "warmup", warmup.fetch("set_type")
    assert_equal "percentage_of_working_load", warmup.fetch("load_strategy")
    assert_equal 65.0, warmup.fetch("load_value")
  end

  test "shows workout template" do
    template = create_template(name: "Upper Body")

    get "/api/v1/workout_templates/#{template.id}"

    assert_response :success
    assert_equal "Upper Body", response.parsed_body.dig("workout_template", "name")
    assert_equal [ "Upper Chest Press" ], response.parsed_body.dig("workout_template", "slots").map { |slot| slot.fetch("label") }
  end

  test "updates workout template with nested slots and lock version" do
    template = create_template(name: "Upper Body")
    slot = template.slots.first
    prescription = slot.set_prescriptions.first

    assert_no_queries_match(/SELECT "workout_session_exercises"\.\*/) do
      assert_queries_match(
        /SELECT DISTINCT .*workout_template_exercise_option_id.*FROM "workout_session_exercises"/,
        count: 1
      ) do
        patch "/api/v1/workout_templates/#{template.id}", params: {
          workout_template: {
            name: "Upper",
            notes: "Updated",
            lock_version: template.lock_version,
            slots: [
              {
                id: slot.id,
                position: 1,
                label: "Incline Press",
                default_exercise_id: incline_press.id,
                rest_seconds: 150,
                lock_version: slot.lock_version,
                exercise_options: [
                  {
                    exercise_id: incline_press.id,
                    position: 1,
                    starting_load_value: 65,
                    next_load_value: 70,
                    progression_increment: 5
                  },
                  {
                    exercise_id: smith_press.id,
                    position: 2,
                    progression_increment: 10
                  }
                ],
                set_prescriptions: [
                  {
                    id: prescription.id,
                    position: 1,
                    set_type: "working",
                    rep_min: 6,
                    rep_max: 10,
                    load_strategy: "working_load"
                  }
                ]
              }
            ]
          }
        }
      end
    end

    assert_response :success
    body = response.parsed_body.fetch("workout_template")
    assert_equal "Upper", body.fetch("name")
    assert_equal 1, body.fetch("lock_version")
    assert_equal "Incline Press", body.dig("slots", 0, "label")
    assert_equal 150, body.dig("slots", 0, "rest_seconds")
    assert_equal [ incline_press.id, smith_press.id ], body.dig("slots", 0, "exercise_options").map { |option| option.fetch("exercise_id") }
    assert_equal [ "working" ], body.dig("slots", 0, "set_prescriptions").map { |set| set.fetch("set_type") }
  end

  test "archives and restores workout template through update" do
    template = create_template(name: "Upper Body")

    patch "/api/v1/workout_templates/#{template.id}", params: {
      workout_template: {
        archived_at: Time.current.iso8601,
        lock_version: template.lock_version
      }
    }

    assert_response :success
    archived_template = response.parsed_body.fetch("workout_template")
    assert_not_nil archived_template.fetch("archived_at")

    patch "/api/v1/workout_templates/#{template.id}", params: {
      workout_template: {
        archived_at: nil,
        lock_version: archived_template.fetch("lock_version")
      }
    }

    assert_response :success
    assert_nil response.parsed_body.dig("workout_template", "archived_at")
  end

  test "returns validation errors" do
    post "/api/v1/workout_templates", params: {
      workout_template: {
        name: "",
        slots: []
      }
    }

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("errors"), {
      "field" => "name",
      "code" => "blank",
      "message" => "Name can't be blank"
    }
  end

  test "returns not found for missing workout template" do
    get "/api/v1/workout_templates/00000000-0000-0000-0000-000000000000"

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  test "returns conflict for stale updates" do
    template = create_template(name: "Upper Body")
    template.update!(notes: "Already changed")

    patch "/api/v1/workout_templates/#{template.id}", params: {
      workout_template: {
        name: "Stale Upper",
        lock_version: 0
      }
    }

    assert_response :conflict
    assert_equal "stale", response.parsed_body.dig("errors", 0, "code")
  end

  private

  def template_payload
    {
      workout_template: {
        name: "Upper Body",
        notes: "Main push/pull upper body day.",
        slots: [
          {
            position: 1,
            label: "Upper Chest Press",
            default_exercise_id: incline_press.id,
            rest_seconds: 180,
            exercise_options: [
              {
                exercise_id: incline_press.id,
                position: 1,
                starting_load_value: 60,
                next_load_value: 65,
                progression_increment: 5
              },
              {
                exercise_id: smith_press.id,
                position: 2,
                progression_increment: 10
              }
            ],
            set_prescriptions: [
              {
                position: 1,
                set_type: "warmup",
                rep_min: 4,
                rep_max: 6,
                load_strategy: "percentage_of_working_load",
                load_value: 65
              },
              {
                position: 2,
                set_type: "working",
                rep_min: 5,
                rep_max: 8,
                load_strategy: "working_load"
              }
            ]
          }
        ]
      }
    }
  end

  def create_template(name:, archived_at: nil)
    template = WorkoutTemplate.create!(name:, archived_at:)
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

  def smith_press
    @smith_press ||= Exercise.create!(
      name: "Incline Smith Press",
      primary_muscle_group: "Chest",
      load_type: "lb"
    )
  end
end
