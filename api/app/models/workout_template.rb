class WorkoutTemplate < ApplicationRecord
  has_many :slots,
           -> { order(:position) },
           class_name: "WorkoutTemplateSlot",
           dependent: :destroy,
           inverse_of: :workout_template

  before_validation :normalize_fields

  validates :name, presence: true

  private

  def normalize_fields
    self.name = name.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
    self.focus_tags = Array(focus_tags).map { |tag| tag.to_s.strip }.reject(&:blank?).uniq
  end
end
