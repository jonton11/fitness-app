module Api
  module V1
    class WorkoutSessionExercisesController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def update
        updated_session_exercise = WorkoutSessionExercises::Substitute.call(
          workout_session_exercise:,
          exercise_option: workout_template_exercise_option,
          attributes: workout_session_exercise_params
        )

        render_resource(
          :workout_session_exercise,
          updated_session_exercise,
          serializer: Api::V1::WorkoutSessionExerciseSerializer
        )
      end

      private

      def workout_session_exercise
        @workout_session_exercise ||= WorkoutSessionExercise
                                        .includes(:workout_session, :workout_session_sets)
                                        .find(params[:id])
      end

      def workout_template_exercise_option
        @workout_template_exercise_option ||= WorkoutTemplateExerciseOption
                                               .includes(:exercise)
                                               .find(workout_session_exercise_params[:workout_template_exercise_option_id])
      end

      def workout_session_exercise_params
        @workout_session_exercise_params ||= params.require(:workout_session_exercise).permit(
          :workout_template_exercise_option_id,
          :lock_version
        )
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end

      def render_not_found(error)
        option_missing = error.model == "WorkoutTemplateExerciseOption"
        render_api_error(
          field: option_missing ? "workout_template_exercise_option_id" : "id",
          code: ERROR_CODE_NOT_FOUND,
          message: option_missing ? "Workout template exercise option not found" : "Workout session exercise not found",
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Workout session exercise has been changed by another request",
          status: :conflict
        )
      end
    end
  end
end
