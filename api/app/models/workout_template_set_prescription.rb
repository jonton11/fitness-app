class WorkoutTemplateSetPrescription < ApplicationRecord
  SET_TYPES = %w[warmup working].freeze
  LOAD_STRATEGIES = %w[
    working_load
    percentage_of_working_load
    explicit
    bodyweight
    none
  ].freeze
  VALUE_LOAD_STRATEGIES = %w[percentage_of_working_load explicit].freeze

  belongs_to :workout_template_slot, inverse_of: :set_prescriptions

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :set_type, inclusion: { in: SET_TYPES }
  validates :rep_min, numericality: { only_integer: true, greater_than: 0 }
  validates :rep_max, numericality: { only_integer: true, greater_than: 0 }
  validates :load_strategy, inclusion: { in: LOAD_STRATEGIES }
  validates :load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :rep_range_is_ordered
  validate :load_value_matches_strategy

  def planned_load_value(planned_working_load_value)
    case load_strategy
    when "working_load"
      planned_working_load_value
    when "percentage_of_working_load"
      return if planned_working_load_value.blank? || load_value.blank?

      planned_working_load_value * load_value / 100
    when "explicit"
      load_value
    end
  end

  private

  def rep_range_is_ordered
    return if rep_min.blank? || rep_max.blank?
    return if rep_max >= rep_min

    errors.add(:rep_max, "must be greater than or equal to rep min")
  end

  def load_value_matches_strategy
    return if load_strategy.blank?

    if VALUE_LOAD_STRATEGIES.include?(load_strategy)
      errors.add(:load_value, "can't be blank") if load_value.blank?
    elsif load_value.present?
      errors.add(:load_value, "must be blank for #{load_strategy}")
    end
  end
end
