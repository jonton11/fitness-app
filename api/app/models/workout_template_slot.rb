class WorkoutTemplateSlot < ApplicationRecord
  belongs_to :workout_template, inverse_of: :slots
  belongs_to :default_exercise, class_name: "Exercise"

  has_many :exercise_options,
           -> { order(:position) },
           class_name: "WorkoutTemplateExerciseOption",
           dependent: :destroy,
           inverse_of: :workout_template_slot
  has_many :set_prescriptions,
           -> { order(:position) },
           class_name: "WorkoutTemplateSetPrescription",
           dependent: :destroy,
           inverse_of: :workout_template_slot

  before_validation :normalize_fields

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :label, presence: true
  validates :rest_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def normalize_fields
    self.label = label.to_s.strip.presence
  end
end
