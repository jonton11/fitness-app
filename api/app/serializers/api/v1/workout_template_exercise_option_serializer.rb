module Api
  module V1
    class WorkoutTemplateExerciseOptionSerializer < ApplicationSerializer
      def initialize(record, completed_history: nil)
        super(record)
        @completed_history = completed_history
      end

      def as_json
        planned_working_load_value = record.planned_working_load_value(completed_history:)

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
          planned_working_load_value: serialize_decimal(planned_working_load_value),
          planned_session_sets: planned_session_sets(planned_working_load_value),
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at)
        }
      end

      private

      attr_reader :completed_history

      def serialize_exercise
        {
          id: record.exercise.id,
          name: record.exercise.name,
          primary_muscle_group: record.exercise.primary_muscle_group,
          load_type: record.exercise.load_type,
          archived_at: serialize_time(record.exercise.archived_at)
        }
      end

      def planned_session_sets(planned_working_load_value)
        record.workout_template_slot.set_prescriptions.sort_by(&:position).map do |prescription|
          {
            workout_template_set_prescription_id: prescription.id,
            planned_load_value: serialize_decimal(
              prescription.planned_load_value(planned_working_load_value)
            )
          }
        end
      end
    end
  end
end
