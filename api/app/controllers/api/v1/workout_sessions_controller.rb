module Api
  module V1
    class WorkoutSessionsController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def create
        started_at = parsed_started_at
        return if performed?

        session = WorkoutSessions::Start.call(
          workout_template: workout_template,
          started_at:
        )

        render_resource(:workout_session, session.reload, serializer: Api::V1::WorkoutSessionSerializer, status: :created)
      end

      def show
        render_resource(:workout_session, workout_session, serializer: Api::V1::WorkoutSessionSerializer)
      end

      def update
        attributes = session_update_attributes
        return if performed?

        unless attributes[:status] == "completed"
          render_api_error(
            field: "status",
            code: ERROR_CODE_INVALID,
            message: "Status must be completed",
            status: :unprocessable_content
          )
          return
        end

        session = WorkoutSessions::Complete.call(
          workout_session:,
          attributes:
        )

        render_resource(:workout_session, session, serializer: Api::V1::WorkoutSessionSerializer)
      end

      private

      def workout_session
        @workout_session ||= WorkoutSession
                             .includes(exercises: [ :selected_exercise, { workout_session_sets: :workout_template_set_prescription } ])
                             .find(params[:id])
      end

      def workout_template
        @workout_template ||= WorkoutTemplate
                              .includes(slots: [ :default_exercise, { exercise_options: :exercise }, :set_prescriptions ])
                              .where(archived_at: nil)
                              .find(session_payload[:workout_template_id])
      end

      def session_payload
        @session_payload ||= params.require(:workout_session).permit(:workout_template_id, :started_at)
      end

      def session_update_payload
        @session_update_payload ||= params.require(:workout_session).permit(:status, :completed_at, :lock_version)
      end

      def session_update_attributes
        session_update_payload.slice(:status, :lock_version).tap do |attributes|
          attributes[:completed_at] = parsed_completed_at if session_update_payload.key?(:completed_at)
        end
      end

      def parsed_started_at
        return Time.current if session_payload[:started_at].blank?

        Time.zone.iso8601(session_payload[:started_at])
      rescue ArgumentError
        render_api_error(
          field: "started_at",
          code: ERROR_CODE_INVALID,
          message: "Started at must be an ISO-8601 timestamp",
          status: :unprocessable_content
        )
      end

      def parsed_completed_at
        return Time.current if session_update_payload[:completed_at].blank?

        Time.zone.iso8601(session_update_payload[:completed_at])
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

      def render_not_found(error)
        render_api_error(
          field: not_found_field(error),
          code: ERROR_CODE_NOT_FOUND,
          message: not_found_message(error),
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Workout session has been changed by another request",
          status: :conflict
        )
      end

      def not_found_field(error)
        error.model == "WorkoutTemplate" ? "workout_template_id" : "id"
      end

      def not_found_message(error)
        error.model == "WorkoutTemplate" ? "Workout template not found" : "Workout session not found"
      end
    end
  end
end
