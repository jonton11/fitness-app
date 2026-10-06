module WorkoutSessionExercises
  class Substitute
    def self.call(...)
      new(...).call
    end

    def initialize(workout_session_exercise:, exercise_option:, attributes:)
      @workout_session_exercise = workout_session_exercise
      @exercise_option = exercise_option
      @attributes = attributes
    end

    def call
      WorkoutSessionExercise.transaction do
        validate_substitution!
        substitute_exercise!
        update_planned_set_loads!
      end

      workout_session_exercise.reload
    end

    private

    attr_reader :workout_session_exercise, :exercise_option, :attributes

    def validate_substitution!
      validate_active_session!
      validate_matching_slot!
      validate_active_exercise!
      validate_pending_sets!
    end

    def validate_active_session!
      return if workout_session_exercise.workout_session.status == "active"

      invalid!(:workout_session, "must be active")
    end

    def validate_matching_slot!
      return if exercise_option.workout_template_slot_id == workout_session_exercise.workout_template_slot_id

      invalid!(:workout_template_exercise_option_id, "must belong to the session exercise slot")
    end

    def validate_active_exercise!
      return if exercise_option.exercise.archived_at.blank?

      invalid!(:workout_template_exercise_option_id, "must reference an active exercise")
    end

    def validate_pending_sets!
      return if workout_session_exercise.workout_session_sets.all? { |set| set.completion_state == "pending" }

      invalid!(:workout_session_sets, "must all be pending before substitution")
    end

    def invalid!(attribute, message)
      workout_session_exercise.errors.add(attribute, message)
      raise ActiveRecord::RecordInvalid, workout_session_exercise
    end

    def substitute_exercise!
      selected_exercise = exercise_option.exercise
      workout_session_exercise.update!(
        workout_template_exercise_option: exercise_option,
        selected_exercise:,
        selected_exercise_name: selected_exercise.name,
        selected_exercise_load_type: selected_exercise.load_type,
        planned_working_load_value:,
        progression_increment: exercise_option.progression_increment,
        lock_version: attributes[:lock_version]
      )
    end

    def update_planned_set_loads!
      workout_session_exercise.workout_session_sets.each do |workout_session_set|
        workout_session_set.update!(
          planned_load_value: planned_load_for(workout_session_set)
        )
      end
    end

    def planned_working_load_value
      @planned_working_load_value ||= exercise_option.planned_working_load_value
    end

    def planned_load_for(workout_session_set)
      case workout_session_set.load_strategy
      when "working_load"
        planned_working_load_value
      when "percentage_of_working_load"
        return if planned_working_load_value.blank? || workout_session_set.prescribed_load_value.blank?

        planned_working_load_value * workout_session_set.prescribed_load_value / 100
      when "explicit"
        workout_session_set.prescribed_load_value
      end
    end
  end
end
