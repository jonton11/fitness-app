class Exercise < ApplicationRecord
  LOAD_TYPES = %w[
    lb
    kg
    machine_stack
    plate_count
    bodyweight
    bodyweight_plus_added
    assisted
    none
  ].freeze

  before_validation :normalize_fields

  validates :name, presence: true
  validates :primary_muscle_group, presence: true
  validates :load_type, presence: true, inclusion: { in: LOAD_TYPES }
  validates :external_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true

  private

  def normalize_fields
    self.name = name.to_s.strip.presence
    self.primary_muscle_group = primary_muscle_group.to_s.strip.presence
    self.load_type = load_type.to_s.strip.presence
    self.external_url = external_url.to_s.strip.presence
    self.secondary_muscle_groups = Array(secondary_muscle_groups).map { |group| group.to_s.strip }.reject(&:blank?)
  end
end
