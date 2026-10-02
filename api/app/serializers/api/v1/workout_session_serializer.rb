module Api
  module V1
    class WorkoutSessionSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          workout_template_id: record.workout_template_id,
          workout_template_name: record.workout_template_name,
          status: record.status,
          started_at: serialize_time(record.started_at),
          completed_at: serialize_time(record.completed_at),
          canceled_at: serialize_time(record.canceled_at),
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at),
          lock_version: record.lock_version,
          exercises: record.exercises.sort_by(&:position).map { |exercise| serialize_session_exercise(exercise) }
        }
      end

      private

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
    end
  end
end
