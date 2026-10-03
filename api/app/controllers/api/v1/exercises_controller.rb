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

        render_collection(
          :exercises,
          exercises,
          serializer: Api::V1::ExerciseSerializer,
          meta: { limit:, offset:, total: }
        )
      end

      def show
        render_resource(:exercise, exercise, serializer: Api::V1::ExerciseSerializer)
      end

      def create
        exercise = Exercise.new(exercise_params)

        if exercise.save
          render_resource(:exercise, exercise, serializer: Api::V1::ExerciseSerializer, status: :created)
        else
          render_validation_errors(exercise)
        end
      end

      def update
        exercise.assign_attributes(exercise_params)

        if exercise.save
          render_resource(:exercise, exercise, serializer: Api::V1::ExerciseSerializer)
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

      def render_not_found
        render_api_error(
          field: "id",
          code: ERROR_CODE_NOT_FOUND,
          message: "Exercise not found",
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Exercise has been changed by another request",
          status: :conflict
        )
      end
    end
  end
end
