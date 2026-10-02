module Api
  module V1
    class WorkoutSessionSetSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          workout_template_set_prescription_id: record.workout_template_set_prescription_id,
          position: record.position,
          set_type: record.set_type,
          target_rep_min: record.target_rep_min,
          target_rep_max: record.target_rep_max,
          load_strategy: record.load_strategy,
          prescribed_load_value: serialize_decimal(record.prescribed_load_value),
          planned_load_value: serialize_decimal(record.planned_load_value),
          actual_reps: record.actual_reps,
          actual_load_value: serialize_decimal(record.actual_load_value),
          completion_state: record.completion_state,
          completed_at: serialize_time(record.completed_at),
          lock_version: record.lock_version,
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at)
        }
      end
    end
  end
end
