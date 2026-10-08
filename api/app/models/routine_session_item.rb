class RoutineSessionItem < ApplicationRecord
  belongs_to :routine_session, inverse_of: :items
  belongs_to :routine_item, optional: true
  belongs_to :exercise, optional: true

  before_validation :normalize_fields

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :routine_session_id }
  validates :exercise_name, presence: true
  validates :target_mode, inclusion: { in: RoutineItem::TARGET_MODES }
  validates :sets, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :target_reps, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :target_duration_seconds, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  private

  def normalize_fields
    self.exercise_name = exercise_name.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end
end
