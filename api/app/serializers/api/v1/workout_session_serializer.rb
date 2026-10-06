module Api
  module V1
    class WorkoutSessionSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          workout_template_id: record.workout_template_id,
          workout_template_name: record.workout_template_name,
          status: record.status,
          started_at: serialize_time(record.started_at),
          completed_at: serialize_time(record.completed_at),
          canceled_at: serialize_time(record.canceled_at),
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at),
          lock_version: record.lock_version,
          exercises: record.exercises.sort_by(&:position).map do |exercise|
            WorkoutSessionExerciseSerializer.new(exercise).as_json
          end
        }
      end
    end
  end
end
