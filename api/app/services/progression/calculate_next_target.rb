module Progression
  class CalculateNextTarget
    WORKING_SET_TYPE = "working"

    Result = Struct.new(:cleared, :next_load_value, keyword_init: true) do
      def cleared?
        cleared
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(session_exercise:)
      @session_exercise = session_exercise
    end

    def call
      current_target = session_exercise.planned_working_load_value
      return result(cleared: false, next_load_value: current_target) if current_target.blank?

      working_sets = required_working_sets
      cleared = working_sets.any? && working_sets.all? { |set| cleared_working_set?(set, current_target) }

      result(
        cleared:,
        next_load_value: cleared ? incremented_target(current_target) : current_target
      )
    end

    private

    attr_reader :session_exercise

    def required_working_sets
      session_exercise.workout_session_sets.select { |set| set.set_type == WORKING_SET_TYPE }
    end

    def cleared_working_set?(set, current_target)
      performed?(set) &&
        set.actual_reps >= set.target_rep_max &&
        performed_load_value(set).present? &&
        performed_load_value(set) >= current_target
    end

    def performed?(set)
      WorkoutSessionSet::PERFORMED_COMPLETION_STATES.include?(set.completion_state)
    end

    def performed_load_value(set)
      set.actual_load_value || set.planned_load_value
    end

    def incremented_target(current_target)
      return current_target if session_exercise.progression_increment.blank?

      current_target + session_exercise.progression_increment
    end

    def result(cleared:, next_load_value:)
      Result.new(cleared:, next_load_value:)
    end
  end
end
