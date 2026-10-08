module Api
  module V1
    class RoutineSessionsController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def index
        sessions = RoutineSession.includes(:items).order(started_at: :desc, created_at: :desc)
        sessions = apply_status_filter(sessions)
        total = sessions.count
        sessions = sessions.limit(limit).offset(offset)

        render_collection(
          :routine_sessions,
          sessions,
          serializer: Api::V1::RoutineSessionSerializer,
          meta: { limit:, offset:, total: }
        )
      end

      def create
        started_at = parsed_started_at
        return if performed?

        result = RoutineSessions::Start.call(
          routine:,
          attributes: session_payload.merge(started_at:)
        )

        render_resource(
          :routine_session,
          result.routine_session.reload,
          serializer: Api::V1::RoutineSessionSerializer,
          status: result.created ? :created : :ok
        )
      end

      def show
        render_resource(
          :routine_session,
          routine_session,
          serializer: Api::V1::RoutineSessionSerializer
        )
      end

      def update
        unless session_update_payload[:status] == "completed"
          render_api_error(
            field: "status",
            code: ERROR_CODE_INVALID,
            message: "Status must be completed",
            status: :unprocessable_content
          )
          return
        end

        attributes = completion_attributes
        return if performed?

        session = RoutineSessions::Complete.call(
          routine_session:,
          attributes:
        )

        render_resource(
          :routine_session,
          session,
          serializer: Api::V1::RoutineSessionSerializer
        )
      end

      private

      def routine
        @routine ||= Routine.includes(items: :exercise).where(archived_at: nil).find(session_payload[:routine_id])
      end

      def routine_session
        @routine_session ||= RoutineSession.includes(:items).find(params[:id])
      end

      def session_payload
        @session_payload ||= params.require(:routine_session).permit(
          :id,
          :routine_id,
          :started_at,
          items: %i[id routine_item_id]
        )
      end

      def session_update_payload
        @session_update_payload ||= params.require(:routine_session).permit(
          :status,
          :completed_at,
          :lock_version
        )
      end

      def completion_attributes
        session_update_payload.slice(:lock_version).tap do |attributes|
          attributes[:completed_at] = parsed_time(session_update_payload[:completed_at], field: "completed_at") if session_update_payload.key?(:completed_at)
        end
      end

      def parsed_started_at
        parsed_time(session_payload[:started_at], field: "started_at", fallback: Time.current)
      end

      def parsed_time(value, field:, fallback: nil)
        return fallback if value.blank?

        Time.iso8601(value)
      rescue ArgumentError
        render_api_error(
          field:,
          code: ERROR_CODE_INVALID,
          message: "#{field.humanize} must be a valid ISO-8601 timestamp",
          status: :unprocessable_content
        )
        nil
      end

      def apply_status_filter(sessions)
        status = params.fetch(:status, "completed")

        case status
        when "all"
          sessions
        when "active", "completed"
          sessions.where(status:)
        else
          sessions.where(status: "completed")
        end
      end

      def limit
        params.fetch(:limit, 50).to_i.clamp(1, 100)
      end

      def offset
        [ params.fetch(:offset, 0).to_i, 0 ].max
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end

      def render_not_found(error)
        routine_missing = error.model == "Routine"
        render_api_error(
          field: routine_missing ? "routine_id" : "id",
          code: ERROR_CODE_NOT_FOUND,
          message: routine_missing ? "Routine not found" : "Routine session not found",
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Routine session has been changed by another request",
          status: :conflict
        )
      end
    end
  end
end
