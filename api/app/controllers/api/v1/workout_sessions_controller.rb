module Api
  module V1
    class WorkoutSessionsController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def index
        sessions = WorkoutSession
                   .includes(exercises: [ :selected_exercise, { workout_session_sets: :workout_template_set_prescription } ])
                   .order(started_at: :desc, created_at: :desc)
        sessions = apply_status_filter(sessions)
        total = sessions.count
        sessions = sessions.limit(limit).offset(offset)

        render_collection(
          :workout_sessions,
          sessions,
          serializer: Api::V1::WorkoutSessionSerializer,
          meta: { limit:, offset:, total: }
        )
      end

      def create
        started_at = parsed_started_at
        return if performed?

        result = if session_payload[:id].present?
          WorkoutSessions::CreateFromSnapshot.call(
            workout_template:,
            attributes: session_payload.merge(started_at:)
          )
        else
          session = WorkoutSessions::Start.call(
            workout_template:,
            started_at:
          )
          WorkoutSessions::CreateFromSnapshot::Result.new(workout_session: session, created: true)
        end

        render_resource(
          :workout_session,
          result.workout_session.reload,
          serializer: Api::V1::WorkoutSessionSerializer,
          status: result.created ? :created : :ok
        )
      end

      def show
        render_resource(:workout_session, workout_session, serializer: Api::V1::WorkoutSessionSerializer)
      end

      def update
        attributes = session_update_attributes
        return if performed?

        session = case attributes[:status]
        when "completed"
          WorkoutSessions::Complete.call(
            workout_session:,
            attributes:
          )
        when "canceled"
          WorkoutSessions::Cancel.call(
            workout_session:,
            attributes:
          )
        else
          render_api_error(
            field: "status",
            code: ERROR_CODE_INVALID,
            message: "Status must be completed or canceled",
            status: :unprocessable_content
          )
          return
        end

        render_resource(:workout_session, session, serializer: Api::V1::WorkoutSessionSerializer)
      end

      private

      def workout_session
        @workout_session ||= WorkoutSession
                             .includes(exercises: [ :selected_exercise, { workout_session_sets: :workout_template_set_prescription } ])
                             .find(params[:id])
      end

      def workout_template
        @workout_template ||= begin
          templates = WorkoutTemplate.includes(slots: [
            :default_exercise,
            :set_prescriptions,
            { exercise_options: [ :exercise, { workout_session_exercises: :workout_session } ] }
          ])
          templates = templates.where(archived_at: nil) if session_payload[:id].blank?
          templates.find(session_payload[:workout_template_id])
        end
      end

      def session_payload
        @session_payload ||= params.require(:workout_session).permit(
          :id,
          :workout_template_id,
          :workout_template_name,
          :started_at,
          exercises: [
            :id,
            :workout_template_slot_id,
            :workout_template_exercise_option_id,
            :selected_exercise_id,
            :position,
            :label,
            :selected_exercise_name,
            :selected_exercise_load_type,
            :rest_seconds,
            :planned_working_load_value,
            :progression_increment,
            workout_session_sets: [
              :id,
              :workout_template_set_prescription_id,
              :position,
              :set_type,
              :target_rep_min,
              :target_rep_max,
              :load_strategy,
              :prescribed_load_value,
              :planned_load_value
            ]
          ]
        )
      end

      def session_update_payload
        @session_update_payload ||= params.require(:workout_session).permit(
          :status,
          :completed_at,
          :canceled_at,
          :lock_version
        )
      end

      def session_update_attributes
        session_update_payload.slice(:status, :lock_version).tap do |attributes|
          attributes[:completed_at] = parsed_completed_at if session_update_payload.key?(:completed_at)
          attributes[:canceled_at] = parsed_canceled_at if session_update_payload.key?(:canceled_at)
        end
      end

      def apply_status_filter(sessions)
        status = params.fetch(:status, "completed")

        case status
        when "all"
          sessions
        when "active", "completed", "canceled"
          sessions.where(status:)
        else
          sessions.where(status: "completed")
        end
      end

      def limit
        requested = params.fetch(:limit, 50).to_i
        requested.clamp(1, 100)
      end

      def offset
        requested = params.fetch(:offset, 0).to_i
        [ requested, 0 ].max
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

      def parsed_canceled_at
        return Time.current if session_update_payload[:canceled_at].blank?

        Time.zone.iso8601(session_update_payload[:canceled_at])
      rescue ArgumentError
        render_api_error(
          field: "canceled_at",
          code: ERROR_CODE_INVALID,
          message: "Canceled at must be an ISO-8601 timestamp",
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
