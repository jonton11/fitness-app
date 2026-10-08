module Api
  module V1
    class RoutinesController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def index
        routines = Routine.includes(items: :exercise).order(:name)
        routines = apply_status_filter(routines)
        routines = apply_search(routines)
        total = routines.count
        routines = routines.limit(limit).offset(offset)

        render_collection(
          :routines,
          routines,
          serializer: Api::V1::RoutineSerializer,
          meta: { limit:, offset:, total: }
        )
      end

      def show
        render_resource(:routine, routine, serializer: Api::V1::RoutineSerializer)
      end

      def create
        routine = Routines::Save.call(routine: Routine.new, payload: routine_payload)

        render_resource(
          :routine,
          routine,
          serializer: Api::V1::RoutineSerializer,
          status: :created
        )
      end

      def update
        updated_routine = Routines::Save.call(routine:, payload: routine_payload)

        render_resource(:routine, updated_routine, serializer: Api::V1::RoutineSerializer)
      end

      private

      def routine
        @routine ||= Routine.includes(items: :exercise).find(params[:id])
      end

      def routine_payload
        @routine_payload ||= params.require(:routine).permit(
          :name,
          :notes,
          :archived_at,
          :lock_version,
          items: [
            :id,
            :position,
            :exercise_id,
            :target_mode,
            :sets,
            :target_reps,
            :target_duration_seconds,
            :notes_override
          ]
        )
      end

      def apply_status_filter(routines)
        case params.fetch(:status, "active")
        when "all"
          routines
        when "archived"
          routines.where.not(archived_at: nil)
        else
          routines.where(archived_at: nil)
        end
      end

      def apply_search(routines)
        query = params[:q].to_s.strip
        return routines if query.blank?

        pattern = "%#{Routine.sanitize_sql_like(query)}%"
        routines.where("name ILIKE :query", query: pattern)
      end

      def limit
        params.fetch(:limit, 50).to_i.clamp(1, 100)
      end

      def offset
        [ params.fetch(:offset, 0).to_i, 0 ].max
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end

      def render_not_found
        render_api_error(
          field: "id",
          code: ERROR_CODE_NOT_FOUND,
          message: "Routine not found",
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Routine has been changed by another request",
          status: :conflict
        )
      end
    end
  end
end
