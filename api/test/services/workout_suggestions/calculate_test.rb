require "test_helper"

module WorkoutSuggestions
  class CalculateTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::TimeHelpers

    test "recent tagged activity changes the least recently trained focus" do
      travel_to Time.zone.parse("2026-10-10 12:00:00") do
        upper = create_template(name: "Upper Body", focus_tags: [ "Upper Body" ])
        lower = create_template(name: "Lower Body", focus_tags: [ "Lower Body" ])
        complete_workout(upper, at: 2.days.ago)
        complete_workout(lower, at: 9.days.ago)

        assert_equal lower, Calculate.call.workout_template

        Activity.create!(
          kind: "basketball",
          started_at: 1.day.ago,
          focus_tags: [ "lower body", "Cardio" ]
        )

        suggestion = Calculate.call
        assert_equal upper, suggestion.workout_template
        assert_equal 2.days.ago, suggestion.last_relevant_at
      end
    end

    test "prioritizes a template whose focus has no recent activity" do
      travel_to Time.zone.parse("2026-10-10 12:00:00") do
        upper = create_template(name: "Upper Body", focus_tags: [ "Upper Body" ])
        core = create_template(name: "Core", focus_tags: [ "Core" ])
        complete_workout(upper, at: 2.days.ago)

        suggestion = Calculate.call
        assert_equal core, suggestion.workout_template
        assert_nil suggestion.last_relevant_at
      end
    end

    test "ignores archived and untagged templates" do
      create_template(name: "No Focus")
      create_template(name: "Archived", focus_tags: [ "Upper Body" ], archived_at: Time.current)

      assert_nil Calculate.call
    end

    private

    def create_template(name:, focus_tags: [], archived_at: nil)
      WorkoutTemplate.create!(name:, focus_tags:, archived_at:)
    end

    def complete_workout(template, at:)
      WorkoutSession.create!(
        workout_template: template,
        workout_template_name: template.name,
        status: "completed",
        started_at: at - 1.hour,
        completed_at: at
      )
    end
  end
end
