class WorkoutTemplateExerciseOption < ApplicationRecord
  belongs_to :workout_template_slot, inverse_of: :exercise_options
  belongs_to :exercise

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :exercise_id, uniqueness: { scope: :workout_template_slot_id }
  validates :starting_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :next_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :progression_increment, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :default_option_matches_slot_default

  private

  def default_option_matches_slot_default
    return unless is_default?
    return if workout_template_slot.blank?
    return if exercise_id == workout_template_slot.default_exercise_id

    errors.add(:exercise_id, "must match the slot default exercise")
  end
end
