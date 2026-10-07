module Progression
  class ApplyCompletedSession
    COMPLETED_STATUS = "completed"

    def self.call(...)
      new(...).call
    end

    def initialize(workout_session:)
      @workout_session = workout_session
    end

    def call
      return workout_session unless workout_session.status == COMPLETED_STATUS

      workout_session.exercises.filter_map(&:workout_template_exercise_option).uniq.each do |option|
        RecalculateFromHistory.call(workout_template_exercise_option: option)
      end

      workout_session
    end

    private

    attr_reader :workout_session
  end
end
