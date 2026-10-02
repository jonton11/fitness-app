class WorkoutSessionSetResult < ApplicationRecord
  COMPLETION_STATES = %w[
    pending
    completed
    attempted_but_target_not_met
    not_performed
  ].freeze

  belongs_to :workout_session_exercise, inverse_of: :set_results
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

  private

  def rep_range_is_ordered
    return if target_rep_min.blank? || target_rep_max.blank?
    return if target_rep_max >= target_rep_min

    errors.add(:target_rep_max, "must be greater than or equal to target rep min")
  end
end
