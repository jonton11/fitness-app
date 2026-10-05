module WorkoutSessions
  class Complete
    def self.call(...)
      new(...).call
    end

    def initialize(workout_session:, attributes:, completed_at: Time.current)
      @workout_session = workout_session
      @attributes = attributes
      @completed_at = completed_at
    end

    def call
      WorkoutSession.transaction do
        workout_session.assign_attributes(completion_attributes)
        mark_pending_sets_not_performed!
        update_exercise_statuses!
        workout_session.save!
      end

      workout_session.reload
    end

    private

    attr_reader :workout_session, :attributes, :completed_at

    def completion_attributes
      attributes.to_h.symbolize_keys.slice(:lock_version).merge(
        status: "completed",
        completed_at: attributes.to_h.symbolize_keys.fetch(:completed_at, completed_at),
        canceled_at: nil
      )
    end

    def mark_pending_sets_not_performed!
      workout_session.exercises.each do |exercise|
        exercise.workout_session_sets.each do |workout_session_set|
          next unless workout_session_set.completion_state == "pending"

          workout_session_set.update!(
            completion_state: "not_performed",
            actual_reps: nil,
            actual_load_value: nil,
            completed_at: nil
          )
        end
      end
    end

    def update_exercise_statuses!
      workout_session.exercises.each do |exercise|
        exercise.update!(status: exercise_performed?(exercise) ? "completed" : "skipped")
      end
    end

    def exercise_performed?(exercise)
      exercise.workout_session_sets.any? do |workout_session_set|
        WorkoutSessionSet::PERFORMED_COMPLETION_STATES.include?(workout_session_set.completion_state)
      end
    end
  end
end
