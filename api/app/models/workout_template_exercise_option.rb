class WorkoutTemplateExerciseOption < ApplicationRecord
  belongs_to :workout_template_slot, inverse_of: :exercise_options
  belongs_to :exercise
  has_many :workout_session_exercises, dependent: :nullify, inverse_of: :workout_template_exercise_option

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :exercise_id, uniqueness: { scope: :workout_template_slot_id }
  validates :starting_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :next_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :calculated_next_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :progression_increment, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :default_option_matches_slot_default

  def planned_working_load_value(completed_history: nil)
    completed_history = completed_history? if completed_history.nil?
    return starting_load_value unless completed_history

    next_load_value || calculated_next_load_value || starting_load_value
  end

  private

  def completed_history?
    if workout_session_exercises.loaded?
      return workout_session_exercises.any? { |session_exercise| session_exercise.workout_session.status == "completed" }
    end

    workout_session_exercises.joins(:workout_session).where(workout_sessions: { status: "completed" }).exists?
  end

  def default_option_matches_slot_default
    return unless is_default?
    return if workout_template_slot.blank?
    return if exercise_id == workout_template_slot.default_exercise_id

    errors.add(:exercise_id, "must match the slot default exercise")
  end
end
