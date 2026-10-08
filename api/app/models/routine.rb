class Routine < ApplicationRecord
  has_many :items,
           -> { order(:position) },
           class_name: "RoutineItem",
           dependent: :destroy,
           inverse_of: :routine

  before_validation :normalize_fields

  validates :name, presence: true

  private

  def normalize_fields
    self.name = name.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end
end
