module Progression
  class RecalculateFromHistory
    COMPLETED_STATUS = "completed"

    def self.call(...)
      new(...).call
    end

    def initialize(workout_template_exercise_option:)
      @workout_template_exercise_option = workout_template_exercise_option
    end

    def call
      calculated_next_load_value = nil

      completed_session_exercises.each do |session_exercise|
        calculated_next_load_value = CalculateNextTarget.call(session_exercise:).next_load_value
      end

      workout_template_exercise_option.update!(calculated_next_load_value:)
      workout_template_exercise_option
    end

    private

    attr_reader :workout_template_exercise_option

    def completed_session_exercises
      workout_template_exercise_option
        .workout_session_exercises
        .joins(:workout_session)
        .includes(:workout_session_sets)
        .where(workout_sessions: { status: COMPLETED_STATUS })
        .order(
          workout_sessions: { started_at: :asc, created_at: :asc },
          workout_session_exercises: { position: :asc }
        )
    end
  end
end
