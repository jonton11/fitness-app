module Routines
  class Save
    def self.call(...)
      new(...).call
    end

    def initialize(routine:, payload:)
      @routine = routine
      @payload = payload
    end

    def call
      Routine.transaction do
        routine.assign_attributes(routine_attributes)
        routine.save!
        sync_items! if payload.key?(:items)
      end

      routine.reload
    end

    private

    attr_reader :routine, :payload

    def routine_attributes
      payload.slice(:name, :notes, :archived_at, :lock_version)
    end

    def sync_items!
      move_existing_items_out_of_range!
      seen_item_ids = []

      Array(payload[:items]).each_with_index do |item_payload, index|
        item = find_or_build_item(item_payload)
        item.assign_attributes(item_attributes(item_payload, index))
        item.save!
        seen_item_ids << item.id
      end

      routine.items.where.not(id: seen_item_ids).destroy_all
    end

    def move_existing_items_out_of_range!
      next_position = routine.items.maximum(:position).to_i + 1

      routine.items.each do |item|
        item.update!(position: next_position)
        next_position += 1
      end
    end

    def find_or_build_item(item_payload)
      return routine.items.build if item_payload[:id].blank?

      routine.items.find(item_payload[:id])
    end

    def item_attributes(item_payload, index)
      item_payload.slice(
        :exercise_id,
        :target_mode,
        :sets,
        :target_reps,
        :target_duration_seconds,
        :notes_override
      ).merge(position: index + 1)
    end
  end
end
