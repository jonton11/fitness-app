module Api
  module V1
    class WorkoutSessionSetsController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def update
        attributes = workout_session_set_attributes
        return if performed?

        updated_workout_session_set = WorkoutSessionSets::Update.call(
          workout_session_set:,
          attributes:
        )

        render_resource(
          :workout_session_set,
          updated_workout_session_set,
          serializer: Api::V1::WorkoutSessionSetSerializer
        )
      end

      private

      def workout_session_set
        @workout_session_set ||= WorkoutSessionSet.find(params[:id])
      end

      def workout_session_set_payload
        @workout_session_set_payload ||= params.require(:workout_session_set).permit(
          :actual_reps,
          :actual_load_value,
          :completion_state,
          :completed_at,
          :lock_version
        )
      end

      def workout_session_set_attributes
        workout_session_set_payload.slice(:actual_reps, :actual_load_value, :completion_state, :lock_version).tap do |attributes|
          attributes[:completed_at] = parsed_completed_at if workout_session_set_payload.key?(:completed_at)
        end
      end

      def parsed_completed_at
        return nil if workout_session_set_payload[:completed_at].blank?

        Time.zone.iso8601(workout_session_set_payload[:completed_at])
      rescue ArgumentError
        render_api_error(
          field: "completed_at",
          code: ERROR_CODE_INVALID,
          message: "Completed at must be an ISO-8601 timestamp",
          status: :unprocessable_content
        )
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end

      def render_not_found
        render_api_error(
          field: "id",
          code: ERROR_CODE_NOT_FOUND,
          message: "Workout session set not found",
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Workout session set has been changed by another request",
          status: :conflict
        )
      end
    end
  end
end
