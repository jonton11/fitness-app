module WorkoutSessions
  class CreateFromSnapshot
    Result = Struct.new(:workout_session, :created, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(workout_template:, attributes:)
      @workout_template = workout_template
      @attributes = attributes.to_h.deep_symbolize_keys
    end

    def call
      existing_session = WorkoutSession.find_by(id: attributes[:id])
      return Result.new(workout_session: existing_session, created: false) if existing_session

      workout_session = WorkoutSession.transaction do
        create_workout_session!
      end

      Result.new(workout_session:, created: true)
    rescue ActiveRecord::RecordNotUnique
      Result.new(workout_session: WorkoutSession.find(attributes[:id]), created: false)
    end

    private

    attr_reader :workout_template, :attributes

    def create_workout_session!
      WorkoutSession.create!(
        id: attributes[:id],
        workout_template:,
        workout_template_name: attributes[:workout_template_name],
        started_at: attributes[:started_at]
      ).tap do |workout_session|
        Array(attributes[:exercises]).each do |exercise_attributes|
          create_session_exercise!(workout_session, exercise_attributes)
        end
      end
    end

    def create_session_exercise!(workout_session, exercise_attributes)
      selected_exercise = Exercise.find(exercise_attributes[:selected_exercise_id])
      workout_template_slot = matching_slot(exercise_attributes)
      session_exercise = workout_session.exercises.create!(
        id: exercise_attributes[:id],
        workout_template_slot:,
        workout_template_exercise_option: matching_option(
          workout_template_slot,
          exercise_attributes,
          selected_exercise
        ),
        selected_exercise:,
        position: exercise_attributes[:position],
        label: exercise_attributes[:label],
        selected_exercise_name: exercise_attributes[:selected_exercise_name],
        selected_exercise_load_type: exercise_attributes[:selected_exercise_load_type],
        rest_seconds: exercise_attributes[:rest_seconds],
        planned_working_load_value: exercise_attributes[:planned_working_load_value],
        progression_increment: exercise_attributes[:progression_increment]
      )

      Array(exercise_attributes[:workout_session_sets]).each do |set_attributes|
        create_session_set!(session_exercise, set_attributes)
      end
    end

    def create_session_set!(session_exercise, set_attributes)
      session_exercise.workout_session_sets.create!(
        id: set_attributes[:id],
        workout_template_set_prescription: matching_prescription(session_exercise, set_attributes),
        position: set_attributes[:position],
        set_type: set_attributes[:set_type],
        target_rep_min: set_attributes[:target_rep_min],
        target_rep_max: set_attributes[:target_rep_max],
        load_strategy: set_attributes[:load_strategy],
        prescribed_load_value: set_attributes[:prescribed_load_value],
        planned_load_value: set_attributes[:planned_load_value]
      )
    end

    def matching_slot(exercise_attributes)
      workout_template.slots.find_by(id: exercise_attributes[:workout_template_slot_id])
    end

    def matching_option(workout_template_slot, exercise_attributes, selected_exercise)
      option_id = exercise_attributes[:workout_template_exercise_option_id]
      return if workout_template_slot.blank? || option_id.blank?

      workout_template_slot.exercise_options.find_by(id: option_id, exercise: selected_exercise)
    end

    def matching_prescription(session_exercise, set_attributes)
      prescription_id = set_attributes[:workout_template_set_prescription_id]
      return if prescription_id.blank?

      session_exercise.workout_template_slot&.set_prescriptions&.find_by(id: prescription_id)
    end
  end
end
