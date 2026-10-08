class Routine < ApplicationRecord
  has_many :items,
           -> { order(:position) },
           class_name: "RoutineItem",
           dependent: :destroy,
           inverse_of: :routine
  has_many :routine_sessions, dependent: :nullify

  before_validation :normalize_fields

  validates :name, presence: true

  private

  def normalize_fields
    self.name = name.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end
end
