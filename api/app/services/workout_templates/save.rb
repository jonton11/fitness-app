module WorkoutTemplates
  class Save
    def self.call(...)
      new(...).call
    end

    def initialize(template:, payload:)
      @template = template
      @payload = payload
    end

    def call
      WorkoutTemplate.transaction do
        template.assign_attributes(template_attributes)
        template.save!
        sync_slots! if payload.key?(:slots)
      end

      template.reload
    end

    private

    attr_reader :template, :payload

    def template_attributes
      payload.slice(:name, :notes, :archived_at, :lock_version)
    end

    def sync_slots!
      seen_slot_ids = []

      Array(payload[:slots]).each_with_index do |slot_payload, index|
        slot = find_or_build_slot(slot_payload)
        slot.assign_attributes(slot_attributes(slot_payload, index))
        slot.save!
        sync_exercise_options!(slot, slot_payload)
        sync_set_prescriptions!(slot, slot_payload)
        seen_slot_ids << slot.id
      end

      template.slots.where.not(id: seen_slot_ids).destroy_all
    end

    def find_or_build_slot(slot_payload)
      return template.slots.build if slot_payload[:id].blank?

      template.slots.find(slot_payload[:id])
    end

    def slot_attributes(slot_payload, index)
      slot_payload.slice(:label, :default_exercise_id, :rest_seconds, :lock_version).merge(
        position: slot_payload[:position].presence || index + 1
      )
    end

    def sync_exercise_options!(slot, slot_payload)
      slot.exercise_options.update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
      seen_option_ids = []

      normalized_option_payloads(slot, slot_payload).each_with_index do |option_payload, index|
        option = find_or_build_option(slot, option_payload)
        option.assign_attributes(option_attributes(slot, option_payload, index))
        option.save!
        seen_option_ids << option.id
      end

      slot.exercise_options.where.not(id: seen_option_ids).destroy_all
    end

    def normalized_option_payloads(slot, slot_payload)
      option_payloads = Array(slot_payload[:exercise_options]).map(&:dup)
      default_exercise_id = slot.default_exercise_id

      if option_payloads.none? { |option_payload| option_payload[:exercise_id] == default_exercise_id }
        option_payloads.unshift({ exercise_id: default_exercise_id, position: 1 })
      end

      option_payloads
    end

    def find_or_build_option(slot, option_payload)
      if option_payload[:id].present?
        slot.exercise_options.find(option_payload[:id])
      else
        slot.exercise_options.find_or_initialize_by(exercise_id: option_payload[:exercise_id])
      end
    end

    def option_attributes(slot, option_payload, index)
      option_payload.slice(
        :exercise_id,
        :starting_load_value,
        :next_load_value,
        :progression_increment
      ).merge(
        position: option_payload[:position].presence || index + 1,
        is_default: option_payload[:exercise_id] == slot.default_exercise_id
      )
    end

    def sync_set_prescriptions!(slot, slot_payload)
      seen_set_ids = []

      Array(slot_payload[:set_prescriptions]).each_with_index do |set_payload, index|
        prescription = find_or_build_set_prescription(slot, set_payload)
        prescription.assign_attributes(set_prescription_attributes(set_payload, index))
        prescription.save!
        seen_set_ids << prescription.id
      end

      slot.set_prescriptions.where.not(id: seen_set_ids).destroy_all
    end

    def find_or_build_set_prescription(slot, set_payload)
      return slot.set_prescriptions.build if set_payload[:id].blank?

      slot.set_prescriptions.find(set_payload[:id])
    end

    def set_prescription_attributes(set_payload, index)
      set_payload.slice(
        :set_type,
        :rep_min,
        :rep_max,
        :load_strategy,
        :load_value
      ).merge(position: set_payload[:position].presence || index + 1)
    end
  end
end
