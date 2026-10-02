class WorkoutSession < ApplicationRecord
  STATUSES = %w[active completed canceled].freeze

  belongs_to :workout_template
  has_many :exercises,
           -> { order(:position) },
           class_name: "WorkoutSessionExercise",
           dependent: :destroy,
           inverse_of: :workout_session

  before_validation :normalize_fields

  validates :workout_template_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  private

  def normalize_fields
    self.workout_template_name = workout_template_name.to_s.strip.presence
  end
end
