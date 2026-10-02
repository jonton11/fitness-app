module Api
  module V1
    class WorkoutSessionsController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

      def create
        started_at = parsed_started_at
        return if performed?

        session = WorkoutSessions::Start.call(
          workout_template: workout_template,
          started_at:
        )

        render json: { workout_session: serialize_session(session.reload) }, status: :created
      end

      def show
        render json: { workout_session: serialize_session(workout_session) }
      end

      private

      def workout_session
        @workout_session ||= WorkoutSession
                             .includes(exercises: [ :selected_exercise, { set_results: :workout_template_set_prescription } ])
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

      def serialize_session(session)
        Api::V1::WorkoutSessionSerializer.new(session).as_json
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

      def not_found_field(error)
        error.model == "WorkoutTemplate" ? "workout_template_id" : "id"
      end

      def not_found_message(error)
        error.model == "WorkoutTemplate" ? "Workout template not found" : "Workout session not found"
      end
    end
  end
end
