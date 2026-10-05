module WorkoutSessionSets
  class Update
    def self.call(...)
      new(...).call
    end

    def initialize(workout_session_set:, attributes:, completed_at: Time.current)
      @workout_session_set = workout_session_set
      @attributes = attributes
      @completed_at = completed_at
    end

    def call
      WorkoutSessionSet.transaction do
        workout_session_set.assign_attributes(update_attributes)
        workout_session_set.save!
        update_completed_session_exercise_status!
      end

      workout_session_set.reload
    end

    private

    attr_reader :workout_session_set, :attributes, :completed_at

    def update_attributes
      attributes.to_h.symbolize_keys.tap do |update|
        was_performed = performed?(workout_session_set.completion_state)
        update[:completion_state] = completion_state_for(update)
        normalize_actuals!(update, was_performed:)
      end
    end

    def completion_state_for(update)
      return update[:completion_state] if update[:completion_state].present?
      return "completed" if update.key?(:actual_reps) && update[:actual_reps].present? && !performed?(workout_session_set.completion_state)

      workout_session_set.completion_state
    end

    def normalize_actuals!(update, was_performed:)
      if performed?(update[:completion_state])
        default_actuals!(update) unless was_performed
      else
        update[:actual_reps] = nil
        update[:actual_load_value] = nil
        update[:completed_at] = nil
      end
    end

    def default_actuals!(update)
      update[:actual_load_value] = workout_session_set.planned_load_value unless update.key?(:actual_load_value)
      update[:completed_at] = completed_at unless update.key?(:completed_at)
    end

    def update_completed_session_exercise_status!
      session_exercise = workout_session_set.workout_session_exercise
      return unless session_exercise.workout_session.status == "completed"

      session_exercise.update!(status: exercise_performed?(session_exercise) ? "completed" : "skipped")
    end

    def exercise_performed?(session_exercise)
      session_exercise.workout_session_sets.any? do |set|
        performed?(set.completion_state)
      end
    end

    def performed?(completion_state)
      WorkoutSessionSet::PERFORMED_COMPLETION_STATES.include?(completion_state)
    end
  end
end
