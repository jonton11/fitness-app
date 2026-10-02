module Api
  module V1
    class WorkoutTemplatesController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def index
        templates = WorkoutTemplate.includes(slots: [ :default_exercise, :exercise_options, :set_prescriptions ]).order(:name)
        templates = apply_status_filter(templates)
        templates = apply_search(templates)
        total = templates.count
        templates = templates.limit(limit).offset(offset)

        render json: {
          workout_templates: templates.map { |template| serialize_template(template) },
          meta: { limit:, offset:, total: }
        }
      end

      def show
        render json: { workout_template: serialize_template(workout_template) }
      end

      def create
        template = WorkoutTemplates::Save.call(
          template: WorkoutTemplate.new,
          payload: template_payload
        )

        render json: { workout_template: serialize_template(template) }, status: :created
      end

      def update
        template = WorkoutTemplates::Save.call(
          template: workout_template,
          payload: template_payload
        )

        render json: { workout_template: serialize_template(template) }
      end

      private

      def workout_template
        @workout_template ||= WorkoutTemplate
                              .includes(slots: [ :default_exercise, :exercise_options, :set_prescriptions ])
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

      def serialize_template(template)
        {
          id: template.id,
          name: template.name,
          notes: template.notes,
          archived_at: serialize_time(template.archived_at),
          created_at: serialize_time(template.created_at),
          updated_at: serialize_time(template.updated_at),
          lock_version: template.lock_version,
          slots: template.slots.sort_by(&:position).map { |slot| serialize_slot(slot) }
        }
      end

      def serialize_slot(slot)
        {
          id: slot.id,
          position: slot.position,
          label: slot.label,
          default_exercise_id: slot.default_exercise_id,
          default_exercise: serialize_exercise(slot.default_exercise),
          rest_seconds: slot.rest_seconds,
          created_at: serialize_time(slot.created_at),
          updated_at: serialize_time(slot.updated_at),
          lock_version: slot.lock_version,
          exercise_options: slot.exercise_options.sort_by(&:position).map { |option| serialize_option(option) },
          set_prescriptions: slot.set_prescriptions.sort_by(&:position).map { |prescription| serialize_set_prescription(prescription) }
        }
      end

      def serialize_option(option)
        {
          id: option.id,
          position: option.position,
          exercise_id: option.exercise_id,
          exercise: serialize_exercise(option.exercise),
          is_default: option.is_default,
          starting_load_value: serialize_decimal(option.starting_load_value),
          next_load_value: serialize_decimal(option.next_load_value),
          progression_increment: serialize_decimal(option.progression_increment),
          created_at: serialize_time(option.created_at),
          updated_at: serialize_time(option.updated_at)
        }
      end

      def serialize_set_prescription(prescription)
        {
          id: prescription.id,
          position: prescription.position,
          set_type: prescription.set_type,
          rep_min: prescription.rep_min,
          rep_max: prescription.rep_max,
          load_strategy: prescription.load_strategy,
          load_value: serialize_decimal(prescription.load_value),
          created_at: serialize_time(prescription.created_at),
          updated_at: serialize_time(prescription.updated_at)
        }
      end

      def serialize_exercise(exercise)
        return nil if exercise.blank?

        {
          id: exercise.id,
          name: exercise.name,
          primary_muscle_group: exercise.primary_muscle_group,
          load_type: exercise.load_type,
          archived_at: serialize_time(exercise.archived_at)
        }
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
