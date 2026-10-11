require "test_helper"

class WorkoutSuggestionsApiTest < ActionDispatch::IntegrationTest
  test "returns the suggested active workout template" do
    template = WorkoutTemplate.create!(name: "Upper Body", focus_tags: [ "Upper Body" ])

    get "/api/v1/workout_suggestion"

    assert_response :success
    assert_equal(
      {
        "workout_template_id" => template.id,
        "workout_template_name" => "Upper Body",
        "focus_tags" => [ "Upper Body" ],
        "last_relevant_at" => nil
      },
      response.parsed_body.fetch("workout_suggestion")
    )
  end

  test "returns no content when no active template has focus tags" do
    WorkoutTemplate.create!(name: "Upper Body")

    get "/api/v1/workout_suggestion"

    assert_response :no_content
  end
end
