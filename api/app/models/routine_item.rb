class RoutineItem < ApplicationRecord
  TARGET_MODES = %w[completion_only reps duration load_optional].freeze

  belongs_to :routine, inverse_of: :items
  belongs_to :exercise
  has_many :routine_session_items, dependent: :nullify

  before_validation :normalize_fields

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :routine_id }
  validates :target_mode, inclusion: { in: TARGET_MODES }
  validates :sets, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :target_reps, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :target_duration_seconds, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  private

  def normalize_fields
    self.notes_override = notes_override.to_s.strip.presence
  end
end
