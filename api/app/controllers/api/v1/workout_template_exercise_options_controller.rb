module Api
  module V1
    class WorkoutTemplateExerciseOptionsController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

      def create
        result = WorkoutTemplateExerciseOptions::Create.call(
          workout_template_slot:,
          exercise: existing_exercise,
          exercise_id: new_exercise_id,
          exercise_attributes: new_exercise_attributes,
          attributes: workout_template_exercise_option_params
        )

        render_resource(
          :workout_template_exercise_option,
          result.exercise_option,
          serializer: Api::V1::WorkoutTemplateExerciseOptionSerializer,
          status: result.created ? :created : :ok
        )
      end

      private

      def workout_template_slot
        @workout_template_slot ||= WorkoutTemplateSlot.find(
          workout_template_exercise_option_params[:workout_template_slot_id]
        )
      end

      def existing_exercise
        return if workout_template_exercise_option_params[:exercise].present?

        @existing_exercise ||= Exercise.where(archived_at: nil).find(
          workout_template_exercise_option_params[:exercise_id]
        )
      end

      def new_exercise_attributes
        workout_template_exercise_option_params[:exercise]
      end

      def new_exercise_id
        return if new_exercise_attributes.blank?

        workout_template_exercise_option_params.require(:exercise_id)
      end

      def workout_template_exercise_option_params
        @workout_template_exercise_option_params ||= params.require(
          :workout_template_exercise_option
        ).permit(
          :workout_template_slot_id,
          :exercise_id,
          :starting_load_value,
          :progression_increment,
          exercise: [
            :name,
            :primary_muscle_group,
            :load_type,
            :notes,
            :external_url,
            { secondary_muscle_groups: [] }
          ]
        )
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end

      def render_not_found(error)
        slot_missing = error.model == "WorkoutTemplateSlot"
        render_api_error(
          field: slot_missing ? "workout_template_slot_id" : "exercise_id",
          code: ERROR_CODE_NOT_FOUND,
          message: slot_missing ? "Workout template slot not found" : "Exercise not found",
          status: :not_found
        )
      end
    end
  end
end
