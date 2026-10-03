class WorkoutSessionExercise < ApplicationRecord
  STATUSES = %w[pending completed skipped].freeze

  belongs_to :workout_session, inverse_of: :exercises
  belongs_to :workout_template_slot, optional: true
  belongs_to :workout_template_exercise_option, optional: true
  belongs_to :selected_exercise, class_name: "Exercise"
  has_many :workout_session_sets,
           -> { order(:position) },
           class_name: "WorkoutSessionSet",
           dependent: :destroy,
           inverse_of: :workout_session_exercise

  before_validation :normalize_fields

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :label, presence: true
  validates :selected_exercise_name, presence: true
  validates :selected_exercise_load_type, inclusion: { in: Exercise::LOAD_TYPES }
  validates :rest_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :planned_working_load_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :progression_increment, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  private

  def normalize_fields
    self.label = label.to_s.strip.presence
    self.selected_exercise_name = selected_exercise_name.to_s.strip.presence
    self.selected_exercise_load_type = selected_exercise_load_type.to_s.strip.presence
  end
end
