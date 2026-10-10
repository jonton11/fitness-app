module Api
  module V1
    class RoutineSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          name: record.name,
          notes: record.notes,
          archived_at: serialize_time(record.archived_at),
          items: record.items.map { |item| serialize_item(item) },
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at),
          lock_version: record.lock_version
        }
      end

      private

      def serialize_item(item)
        {
          id: item.id,
          position: item.position,
          exercise_id: item.exercise_id,
          exercise: ExerciseSerializer.new(item.exercise).as_json,
          target_mode: item.target_mode,
          sets: item.sets,
          target_reps: item.target_reps,
          target_duration_seconds: item.target_duration_seconds,
          notes_override: item.notes_override,
          created_at: serialize_time(item.created_at),
          updated_at: serialize_time(item.updated_at)
        }
      end
    end
  end
end
