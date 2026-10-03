class WorkoutSessionSet < ApplicationRecord
  COMPLETION_STATES = %w[
    pending
    completed
    attempted_but_target_not_met
    not_performed
  ].freeze
  PERFORMED_COMPLETION_STATES = %w[completed attempted_but_target_not_met].freeze

  belongs_to :workout_session_exercise, inverse_of: :workout_session_sets
  belongs_to :workout_template_set_prescription, optional: true

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :set_type, inclusion: { in: WorkoutTemplateSetPrescription::SET_TYPES }
  validates :target_rep_min, numericality: { only_integer: true, greater_than: 0 }
  validates :target_rep_max, numericality: { only_integer: true, greater_than: 0 }
  validates :load_strategy, inclusion: { in: WorkoutTemplateSetPrescription::LOAD_STRATEGIES }
  validates :prescribed_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :planned_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :actual_reps, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :actual_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :completion_state, inclusion: { in: COMPLETION_STATES }
  validate :rep_range_is_ordered
  validate :actuals_match_completion_state

  private

  def rep_range_is_ordered
    return if target_rep_min.blank? || target_rep_max.blank?
    return if target_rep_max >= target_rep_min

    errors.add(:target_rep_max, "must be greater than or equal to target rep min")
  end

  def actuals_match_completion_state
    if performed?
      errors.add(:actual_reps, :blank) if actual_reps.nil?
      errors.add(:completed_at, :blank) if completed_at.blank?
    else
      errors.add(:actual_reps, :present, message: "must be blank unless the set was performed") if actual_reps.present?
      if actual_load_value.present?
        errors.add(:actual_load_value, :present, message: "must be blank unless the set was performed")
      end
      errors.add(:completed_at, :present, message: "must be blank unless the set was performed") if completed_at.present?
    end
  end

  def performed?
    PERFORMED_COMPLETION_STATES.include?(completion_state)
  end
end
