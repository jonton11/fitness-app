module Api
  module V1
    class WorkoutTemplatesController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def index
        templates = WorkoutTemplate
                    .includes(slots: [ :default_exercise, { exercise_options: :exercise }, :set_prescriptions ])
                    .order(:name)
        templates = apply_status_filter(templates)
        templates = apply_search(templates)
        total = templates.count
        templates = templates.limit(limit).offset(offset)

        render_collection(
          :workout_templates,
          templates,
          serializer: Api::V1::WorkoutTemplateSerializer,
          meta: { limit:, offset:, total: }
        )
      end

      def show
        render_resource(:workout_template, workout_template, serializer: Api::V1::WorkoutTemplateSerializer)
      end

      def create
        template = WorkoutTemplates::Save.call(
          template: WorkoutTemplate.new,
          payload: template_payload
        )

        render_resource(:workout_template, template, serializer: Api::V1::WorkoutTemplateSerializer, status: :created)
      end

      def update
        template = WorkoutTemplates::Save.call(
          template: workout_template,
          payload: template_payload
        )

        render_resource(:workout_template, template, serializer: Api::V1::WorkoutTemplateSerializer)
      end

      private

      def workout_template
        @workout_template ||= WorkoutTemplate
                              .includes(slots: [ :default_exercise, { exercise_options: :exercise }, :set_prescriptions ])
                              .find(params[:id])
      end

      def template_payload
        @template_payload ||= params.require(:workout_template).permit(
          :name,
          :notes,
          :archived_at,
          :lock_version,
          slots: [
            :id,
            :position,
            :label,
            :default_exercise_id,
            :rest_seconds,
            :lock_version,
            {
              exercise_options: [
                :id,
                :position,
                :exercise_id,
                :is_default,
                :starting_load_value,
                :next_load_value,
                :progression_increment
              ],
              set_prescriptions: [
                :id,
                :position,
                :set_type,
                :rep_min,
                :rep_max,
                :load_strategy,
                :load_value
              ]
            }
          ]
        )
      end

      def apply_status_filter(templates)
        case params.fetch(:status, "active")
        when "all"
          templates
        when "archived"
          templates.where.not(archived_at: nil)
        else
          templates.where(archived_at: nil)
        end
      end

      def apply_search(templates)
        query = params[:q].to_s.strip
        return templates if query.blank?

        pattern = "%#{WorkoutTemplate.sanitize_sql_like(query)}%"
        templates.where("name ILIKE :query", query: pattern)
      end

      def limit
        requested = params.fetch(:limit, 50).to_i
        requested.clamp(1, 100)
      end

      def offset
        requested = params.fetch(:offset, 0).to_i
        [ requested, 0 ].max
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end

      def render_not_found
        render_api_error(
          field: "id",
          code: ERROR_CODE_NOT_FOUND,
          message: "Workout template not found",
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Workout template has been changed by another request",
          status: :conflict
        )
      end
    end
  end
end
