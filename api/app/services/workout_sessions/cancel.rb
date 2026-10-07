module WorkoutSessions
  class Cancel
    ACTIVE_STATUS = "active"

    def self.call(...)
      new(...).call
    end

    def initialize(workout_session:, attributes:, canceled_at: Time.current)
      @workout_session = workout_session
      @attributes = attributes
      @canceled_at = canceled_at
    end

    def call
      ensure_active_session!
      workout_session.update!(cancel_attributes)

      workout_session.reload
    end

    private

    attr_reader :workout_session, :attributes, :canceled_at

    def cancel_attributes
      update_attributes = attributes.to_h.symbolize_keys
      update_attributes.slice(:lock_version).merge(
        status: "canceled",
        completed_at: nil,
        canceled_at: update_attributes.fetch(:canceled_at, canceled_at)
      )
    end

    def ensure_active_session!
      return if workout_session.status == ACTIVE_STATUS

      workout_session.errors.add(:status, "must be active")
      raise ActiveRecord::RecordInvalid, workout_session
    end
  end
end
