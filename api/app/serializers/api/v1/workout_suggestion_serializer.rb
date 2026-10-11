module Api
  module V1
    class WorkoutSuggestionSerializer < ApplicationSerializer
      def as_json
        {
          workout_template_id: record.workout_template.id,
          workout_template_name: record.workout_template.name,
          focus_tags: record.workout_template.focus_tags,
          last_relevant_at: serialize_time(record.last_relevant_at)
        }
      end
    end
  end
end
