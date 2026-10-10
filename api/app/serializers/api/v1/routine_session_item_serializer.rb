module Api
  module V1
    class RoutineSessionItemSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          routine_item_id: record.routine_item_id,
          exercise_id: record.exercise_id,
          position: record.position,
          exercise_name: record.exercise_name,
          target_mode: record.target_mode,
          sets: record.sets,
          target_reps: record.target_reps,
          target_duration_seconds: record.target_duration_seconds,
          notes: record.notes,
          completed_at: serialize_time(record.completed_at),
          lock_version: record.lock_version
        }
      end
    end
  end
end
