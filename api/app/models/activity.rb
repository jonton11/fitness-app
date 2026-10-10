class Activity < ApplicationRecord
  KINDS = %w[basketball rest_day recovery other].freeze
  SOURCES = %w[manual].freeze

  before_validation :normalize_fields

  validates :kind, inclusion: { in: KINDS }
  validates :source, inclusion: { in: SOURCES }
  validates :started_at, presence: true
  validate :ended_at_follows_started_at

  private

  def normalize_fields
    self.kind = kind.to_s.strip.presence
    self.source = source.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
    self.focus_tags = Array(focus_tags).map { |tag| tag.to_s.strip }.reject(&:blank?).uniq
  end

  def ended_at_follows_started_at
    return if ended_at.blank? || started_at.blank? || ended_at >= started_at

    errors.add(:ended_at, :invalid, message: "must be at or after the start time")
  end
end
