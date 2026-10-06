module Api
  module V1
    class WorkoutTemplateExerciseOptionSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          position: record.position,
          exercise_id: record.exercise_id,
          exercise: serialize_exercise,
          is_default: record.is_default,
          starting_load_value: serialize_decimal(record.starting_load_value),
          next_load_value: serialize_decimal(record.next_load_value),
          calculated_next_load_value: serialize_decimal(record.calculated_next_load_value),
          progression_increment: serialize_decimal(record.progression_increment),
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at)
        }
      end

      private

      def serialize_exercise
        {
          id: record.exercise.id,
          name: record.exercise.name,
          primary_muscle_group: record.exercise.primary_muscle_group,
          load_type: record.exercise.load_type,
          archived_at: serialize_time(record.exercise.archived_at)
        }
      end
    end
  end
end
