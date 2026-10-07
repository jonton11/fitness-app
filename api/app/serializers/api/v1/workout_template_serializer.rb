module Api
  module V1
    class WorkoutTemplateSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          name: record.name,
          notes: record.notes,
          archived_at: serialize_time(record.archived_at),
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at),
          lock_version: record.lock_version,
          slots: record.slots.sort_by(&:position).map { |slot| serialize_slot(slot) }
        }
      end

      private

      def serialize_slot(slot)
        {
          id: slot.id,
          position: slot.position,
          label: slot.label,
          default_exercise_id: slot.default_exercise_id,
          default_exercise: serialize_exercise(slot.default_exercise),
          rest_seconds: slot.rest_seconds,
          created_at: serialize_time(slot.created_at),
          updated_at: serialize_time(slot.updated_at),
          lock_version: slot.lock_version,
          exercise_options: slot.exercise_options.sort_by(&:position).map { |option| serialize_option(option) },
          set_prescriptions: slot.set_prescriptions.sort_by(&:position).map { |prescription| serialize_set_prescription(prescription) }
        }
      end

      def serialize_option(option)
        {
          id: option.id,
          position: option.position,
          exercise_id: option.exercise_id,
          exercise: serialize_exercise(option.exercise),
          is_default: option.is_default,
          starting_load_value: serialize_decimal(option.starting_load_value),
          next_load_value: serialize_decimal(option.next_load_value),
          calculated_next_load_value: serialize_decimal(option.calculated_next_load_value),
          progression_increment: serialize_decimal(option.progression_increment),
          created_at: serialize_time(option.created_at),
          updated_at: serialize_time(option.updated_at)
        }
      end

      def serialize_set_prescription(prescription)
        {
          id: prescription.id,
          position: prescription.position,
          set_type: prescription.set_type,
          rep_min: prescription.rep_min,
          rep_max: prescription.rep_max,
          load_strategy: prescription.load_strategy,
          load_value: serialize_decimal(prescription.load_value),
          created_at: serialize_time(prescription.created_at),
          updated_at: serialize_time(prescription.updated_at)
        }
      end

      def serialize_exercise(exercise)
        return nil if exercise.blank?

        {
          id: exercise.id,
          name: exercise.name,
          primary_muscle_group: exercise.primary_muscle_group,
          load_type: exercise.load_type,
          archived_at: serialize_time(exercise.archived_at)
        }
      end
    end
  end
end
