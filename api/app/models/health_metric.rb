class HealthMetric < ApplicationRecord
  METRIC_UNITS = {
    "body_weight" => "kg",
    "body_fat_percentage" => "percent",
    "steps" => "count",
    "active_energy" => "kcal",
    "sleep_duration" => "minutes",
    "resting_heart_rate" => "bpm"
  }.freeze
  SOURCES = %w[healthkit].freeze

  belongs_to :user

  before_validation :normalize_fields

  validates :id, presence: true
  validates :kind, inclusion: { in: METRIC_UNITS.keys }
  validates :value, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :started_at, :ended_at, presence: true
  validate :unit_matches_kind
  validate :ended_at_follows_started_at

  private

  def normalize_fields
    self.kind = kind.to_s.strip.presence
    self.unit = unit.to_s.strip.presence
    self.source = source.to_s.strip.presence
  end

  def unit_matches_kind
    expected_unit = METRIC_UNITS[kind]
    return if expected_unit.blank? || unit.blank? || unit == expected_unit

    errors.add(:unit, :invalid, message: "must be #{expected_unit} for #{kind.humanize.downcase}")
  end

  def ended_at_follows_started_at
    return if ended_at.blank? || started_at.blank? || ended_at >= started_at

    errors.add(:ended_at, :invalid, message: "must be at or after the start time")
  end
end
