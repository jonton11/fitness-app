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
          workout_session_sets: session_exercise.workout_session_sets.sort_by(&:position).map { |workout_session_set| serialize_workout_session_set(workout_session_set) }
        }
      end

      def serialize_workout_session_set(workout_session_set)
        WorkoutSessionSetSerializer.new(workout_session_set).as_json
      end
    end
  end
end
