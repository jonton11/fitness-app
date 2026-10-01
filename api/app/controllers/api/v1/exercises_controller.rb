module Api
  module V1
    class ExercisesController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def index
        exercises = Exercise.order(:name)
        exercises = apply_status_filter(exercises)
        exercises = apply_search(exercises)
        total = exercises.count
        exercises = exercises.limit(limit).offset(offset)

        render json: {
          exercises: exercises.map { |exercise| serialize_exercise(exercise) },
          meta: { limit:, offset:, total: }
        }
      end

      def show
        render json: { exercise: serialize_exercise(exercise) }
      end

      def create
        exercise = Exercise.new(exercise_params)

        if exercise.save
          render json: { exercise: serialize_exercise(exercise) }, status: :created
        else
          render_validation_errors(exercise)
        end
      end

      def update
        exercise.assign_attributes(exercise_params)

        if exercise.save
          render json: { exercise: serialize_exercise(exercise) }
        else
          render_validation_errors(exercise)
        end
      end

      private

      def exercise
        @exercise ||= Exercise.find(params[:id])
      end

      def exercise_params
        params.require(:exercise).permit(
          :name,
          :primary_muscle_group,
          :load_type,
          :notes,
          :external_url,
          :archived_at,
          :lock_version,
          secondary_muscle_groups: []
        )
      end

      def apply_status_filter(exercises)
        case params.fetch(:status, "active")
        when "all"
          exercises
        when "archived"
          exercises.where.not(archived_at: nil)
        else
          exercises.where(archived_at: nil)
        end
      end

      def apply_search(exercises)
        query = params[:q].to_s.strip
        return exercises if query.blank?

        pattern = "%#{Exercise.sanitize_sql_like(query)}%"
        exercises.where(
          "name ILIKE :query OR primary_muscle_group ILIKE :query",
          query: pattern
        )
      end

      def limit
        requested = params.fetch(:limit, 50).to_i
        requested.clamp(1, 100)
      end

      def offset
        requested = params.fetch(:offset, 0).to_i
        [ requested, 0 ].max
      end

      def serialize_exercise(exercise)
        {
          id: exercise.id,
          name: exercise.name,
          primary_muscle_group: exercise.primary_muscle_group,
          secondary_muscle_groups: exercise.secondary_muscle_groups,
          load_type: exercise.load_type,
          notes: exercise.notes,
          external_url: exercise.external_url,
          archived_at: serialize_time(exercise.archived_at),
          created_at: serialize_time(exercise.created_at),
          updated_at: serialize_time(exercise.updated_at),
          lock_version: exercise.lock_version
        }
      end

      def serialize_time(value)
        value&.utc&.iso8601(3)
      end

      def render_validation_errors(record)
        render json: {
          errors: record.errors.map do |error|
            {
              field: error.attribute.to_s,
              code: error.type.to_s,
              message: error.full_message
            }
          end
        }, status: :unprocessable_content
      end

      def render_not_found
        render json: {
          errors: [
            {
              field: "id",
              code: "not_found",
              message: "Exercise not found"
            }
          ]
        }, status: :not_found
      end

      def render_conflict
        render json: {
          errors: [
            {
              field: "lock_version",
              code: "stale",
              message: "Exercise has been changed by another request"
            }
          ]
        }, status: :conflict
      end
    end
  end
end
