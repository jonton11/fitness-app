module Api
  module V1
    class WorkoutSessionExerciseSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          workout_template_slot_id: record.workout_template_slot_id,
          workout_template_exercise_option_id: record.workout_template_exercise_option_id,
          position: record.position,
          label: record.label,
          selected_exercise_id: record.selected_exercise_id,
          selected_exercise: {
            id: record.selected_exercise_id,
            name: record.selected_exercise_name,
            load_type: record.selected_exercise_load_type
          },
          rest_seconds: record.rest_seconds,
          planned_working_load_value: serialize_decimal(record.planned_working_load_value),
          progression_increment: serialize_decimal(record.progression_increment),
          status: record.status,
          lock_version: record.lock_version,
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at),
          workout_session_sets: record.workout_session_sets.sort_by(&:position).map do |workout_session_set|
            WorkoutSessionSetSerializer.new(workout_session_set).as_json
          end
        }
      end
    end
  end
end
