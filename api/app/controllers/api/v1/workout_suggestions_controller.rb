module Api
  module V1
    class WorkoutSuggestionsController < ApplicationController
      def show
        suggestion = WorkoutSuggestions::Calculate.call
        return head :no_content if suggestion.blank?

        render_resource(
          :workout_suggestion,
          suggestion,
          serializer: Api::V1::WorkoutSuggestionSerializer
        )
      end
    end
  end
end
