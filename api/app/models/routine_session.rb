class RoutineSession < ApplicationRecord
  STATUSES = %w[active completed].freeze

  belongs_to :routine, optional: true
  has_many :items,
           -> { order(:position) },
           class_name: "RoutineSessionItem",
           dependent: :destroy,
           inverse_of: :routine_session

  before_validation :normalize_fields

  validates :routine_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  validate :completion_matches_status

  private

  def normalize_fields
    self.routine_name = routine_name.to_s.strip.presence
  end

  def completion_matches_status
    if status == "completed" && completed_at.blank?
      errors.add(:completed_at, :blank)
    elsif status == "active" && completed_at.present?
      errors.add(:completed_at, :present, message: "must be blank while the routine is active")
    end
  end
end
