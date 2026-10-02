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
        {
          id: session.id,
          workout_template_id: session.workout_template_id,
          workout_template_name: session.workout_template_name,
          status: session.status,
          started_at: serialize_time(session.started_at),
          completed_at: serialize_time(session.completed_at),
          canceled_at: serialize_time(session.canceled_at),
          created_at: serialize_time(session.created_at),
          updated_at: serialize_time(session.updated_at),
          lock_version: session.lock_version,
          exercises: session.exercises.sort_by(&:position).map { |exercise| serialize_session_exercise(exercise) }
        }
      end

      def serialize_session_exercise(session_exercise)
        {
          id: session_exercise.id,
          workout_template_slot_id: session_exercise.workout_template_slot_id,
          workout_template_exercise_option_id: session_exercise.workout_template_exercise_option_id,
          position: session_exercise.position,
          label: session_exercise.label,
          selected_exercise_id: session_exercise.selected_exercise_id,
          selected_exercise: {
            id: session_exercise.selected_exercise_id,
            name: session_exercise.selected_exercise_name,
            load_type: session_exercise.selected_exercise_load_type
          },
          rest_seconds: session_exercise.rest_seconds,
          planned_working_load_value: serialize_decimal(session_exercise.planned_working_load_value),
          progression_increment: serialize_decimal(session_exercise.progression_increment),
          status: session_exercise.status,
          created_at: serialize_time(session_exercise.created_at),
          updated_at: serialize_time(session_exercise.updated_at),
          set_results: session_exercise.set_results.sort_by(&:position).map { |set_result| serialize_set_result(set_result) }
        }
      end

      def serialize_set_result(set_result)
        {
          id: set_result.id,
          workout_template_set_prescription_id: set_result.workout_template_set_prescription_id,
          position: set_result.position,
          set_type: set_result.set_type,
          target_rep_min: set_result.target_rep_min,
          target_rep_max: set_result.target_rep_max,
          load_strategy: set_result.load_strategy,
          prescribed_load_value: serialize_decimal(set_result.prescribed_load_value),
          planned_load_value: serialize_decimal(set_result.planned_load_value),
          actual_reps: set_result.actual_reps,
          actual_load_value: serialize_decimal(set_result.actual_load_value),
          completion_state: set_result.completion_state,
          completed_at: serialize_time(set_result.completed_at),
          created_at: serialize_time(set_result.created_at),
          updated_at: serialize_time(set_result.updated_at)
        }
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
