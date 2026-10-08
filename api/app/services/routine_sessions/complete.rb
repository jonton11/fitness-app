module RoutineSessions
  class Complete
    def self.call(...)
      new(...).call
    end

    def initialize(routine_session:, attributes:, completed_at: Time.current)
      @routine_session = routine_session
      @attributes = attributes.to_h.symbolize_keys
      @completed_at = completed_at
    end

    def call
      ensure_all_items_completed!
      routine_session.update!(attributes.slice(:lock_version).merge(
        status: "completed",
        completed_at: attributes.fetch(:completed_at, completed_at)
      ))
      routine_session.reload
    end

    private

    attr_reader :routine_session, :attributes, :completed_at

    def ensure_all_items_completed!
      return if routine_session.items.all? { |item| item.completed_at.present? }

      routine_session.errors.add(:base, "Complete every routine item before finishing")
      raise ActiveRecord::RecordInvalid, routine_session
    end
  end
end
