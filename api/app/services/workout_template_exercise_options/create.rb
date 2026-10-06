module WorkoutTemplateExerciseOptions
  class Create
    Result = Struct.new(:exercise_option, :created, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(workout_template_slot:, attributes:, exercise: nil, exercise_attributes: nil)
      @workout_template_slot = workout_template_slot
      @exercise = exercise
      @exercise_attributes = exercise_attributes
      @attributes = attributes
    end

    def call
      result = nil

      WorkoutTemplateSlot.transaction do
        workout_template_slot.lock!
        exercise = find_or_create_exercise!
        exercise_option = workout_template_slot.exercise_options.find_or_initialize_by(exercise:)
        created = exercise_option.new_record?
        exercise_option.assign_attributes(option_attributes(exercise_option))
        slot_changed = exercise_option.has_changes_to_save?
        exercise_option.save!
        workout_template_slot.touch if slot_changed
        result = Result.new(exercise_option:, created:)
      end

      result
    end

    private

    attr_reader :workout_template_slot, :exercise, :exercise_attributes, :attributes

    def find_or_create_exercise!
      exercise || Exercise.create!(exercise_attributes)
    end

    def option_attributes(exercise_option)
      attributes.to_h.symbolize_keys.slice(:starting_load_value, :progression_increment).tap do |option_attributes|
        option_attributes[:position] = next_position if exercise_option.new_record?
      end
    end

    def next_position
      workout_template_slot.exercise_options.maximum(:position).to_i + 1
    end
  end
end
