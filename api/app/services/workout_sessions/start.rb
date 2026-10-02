module WorkoutSessions
  class Start
    def self.call(...)
      new(...).call
    end

    def initialize(workout_template:, started_at: Time.current)
      @workout_template = workout_template
      @started_at = started_at
    end

    def call
      WorkoutSession.transaction do
        WorkoutSession.create!(
          workout_template:,
          workout_template_name: workout_template.name,
          started_at:
        ).tap { |session| snapshot_exercises!(session) }
      end
    end

    private

    attr_reader :workout_template, :started_at

    def snapshot_exercises!(session)
      workout_template.slots.each do |slot|
        option = default_option_for(slot)
        selected_exercise = option&.exercise || slot.default_exercise
        planned_working_load_value = planned_working_load_for(option)
        session_exercise = session.exercises.create!(
          workout_template_slot: slot,
          workout_template_exercise_option: option,
          selected_exercise:,
          position: slot.position,
          label: slot.label,
          selected_exercise_name: selected_exercise.name,
          selected_exercise_load_type: selected_exercise.load_type,
          rest_seconds: slot.rest_seconds,
          planned_working_load_value:,
          progression_increment: option&.progression_increment
        )

        snapshot_workout_session_sets!(session_exercise, slot, planned_working_load_value)
      end
    end

    def snapshot_workout_session_sets!(session_exercise, slot, planned_working_load_value)
      slot.set_prescriptions.each do |prescription|
        session_exercise.workout_session_sets.create!(
          workout_template_set_prescription: prescription,
          position: prescription.position,
          set_type: prescription.set_type,
          target_rep_min: prescription.rep_min,
          target_rep_max: prescription.rep_max,
          load_strategy: prescription.load_strategy,
          prescribed_load_value: prescription.load_value,
          planned_load_value: planned_load_for(prescription, planned_working_load_value)
        )
      end
    end

    def default_option_for(slot)
      slot.exercise_options.find(&:is_default?) ||
        slot.exercise_options.find { |option| option.exercise_id == slot.default_exercise_id }
    end

    def planned_working_load_for(option)
      option&.starting_load_value || option&.next_load_value
    end

    def planned_load_for(prescription, planned_working_load_value)
      case prescription.load_strategy
      when "working_load"
        planned_working_load_value
      when "percentage_of_working_load"
        return nil if planned_working_load_value.blank? || prescription.load_value.blank?

        planned_working_load_value * prescription.load_value / 100
      when "explicit"
        prescription.load_value
      end
    end
  end
end
