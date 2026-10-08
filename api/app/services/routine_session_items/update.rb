module RoutineSessionItems
  class Update
    def self.call(...)
      new(...).call
    end

    def initialize(routine_session_item:, attributes:, completed_at: Time.current)
      @routine_session_item = routine_session_item
      @attributes = attributes.to_h.symbolize_keys
      @completed_at = completed_at
    end

    def call
      ensure_session_is_active!
      routine_session_item.update!(update_attributes)
      routine_session_item.reload
    end

    private

    attr_reader :routine_session_item, :attributes, :completed_at

    def ensure_session_is_active!
      return if routine_session_item.routine_session.status == "active"

      routine_session_item.errors.add(:base, "Completed routine history cannot be changed")
      raise ActiveRecord::RecordInvalid, routine_session_item
    end

    def update_attributes
      attributes.slice(:lock_version).merge(
        completed_at: completed? ? attributes.fetch(:completed_at, completed_at) || completed_at : nil
      )
    end

    def completed?
      ActiveModel::Type::Boolean.new.cast(attributes.fetch(:completed))
    end
  end
end
