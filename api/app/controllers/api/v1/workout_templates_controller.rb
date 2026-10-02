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
        template = WorkoutTemplate.new(template_attributes)
        save_template(template, status: :created)
      end

      def update
        workout_template.assign_attributes(template_attributes)
        save_template(workout_template)
      end

      private

      def workout_template
        @workout_template ||= WorkoutTemplate
                              .includes(slots: [ :default_exercise, :exercise_options, :set_prescriptions ])
                              .find(params[:id])
      end

      def save_template(template, status: :ok)
        WorkoutTemplate.transaction do
          unless template.save
            render_validation_errors(template)
            raise ActiveRecord::Rollback
          end

          sync_slots!(template) if template_payload.key?(:slots)
        end

        return if performed?

        template.reload
        render json: { workout_template: serialize_template(template) }, status:
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

      def template_attributes
        template_payload.slice(:name, :notes, :archived_at, :lock_version)
      end

      def sync_slots!(template)
        seen_slot_ids = []

        Array(template_payload[:slots]).each_with_index do |slot_payload, index|
          slot = find_or_build_slot(template, slot_payload)
          slot.assign_attributes(slot_attributes(slot_payload, index))
          slot.save!
          sync_exercise_options!(slot, slot_payload)
          sync_set_prescriptions!(slot, slot_payload)
          seen_slot_ids << slot.id
        end

        template.slots.where.not(id: seen_slot_ids).destroy_all
      end

      def find_or_build_slot(template, slot_payload)
        return template.slots.build if slot_payload[:id].blank?

        template.slots.find(slot_payload[:id])
      end

      def slot_attributes(slot_payload, index)
        slot_payload.slice(:label, :default_exercise_id, :rest_seconds, :lock_version).merge(
          position: slot_payload[:position].presence || index + 1
        )
      end

      def sync_exercise_options!(slot, slot_payload)
        slot.exercise_options.update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
        seen_option_ids = []

        normalized_option_payloads(slot, slot_payload).each_with_index do |option_payload, index|
          option = find_or_build_option(slot, option_payload)
          option.assign_attributes(option_attributes(slot, option_payload, index))
          option.save!
          seen_option_ids << option.id
        end

        slot.exercise_options.where.not(id: seen_option_ids).destroy_all
      end

      def normalized_option_payloads(slot, slot_payload)
        option_payloads = Array(slot_payload[:exercise_options]).map(&:dup)
        default_exercise_id = slot.default_exercise_id

        if option_payloads.none? { |option_payload| option_payload[:exercise_id] == default_exercise_id }
          option_payloads.unshift({ exercise_id: default_exercise_id, position: 1 })
        end

        option_payloads
      end

      def find_or_build_option(slot, option_payload)
        if option_payload[:id].present?
          slot.exercise_options.find(option_payload[:id])
        else
          slot.exercise_options.find_or_initialize_by(exercise_id: option_payload[:exercise_id])
        end
      end

      def option_attributes(slot, option_payload, index)
        option_payload.slice(
          :exercise_id,
          :starting_load_value,
          :next_load_value,
          :progression_increment
        ).merge(
          position: option_payload[:position].presence || index + 1,
          is_default: option_payload[:exercise_id] == slot.default_exercise_id
        )
      end

      def sync_set_prescriptions!(slot, slot_payload)
        seen_set_ids = []

        Array(slot_payload[:set_prescriptions]).each_with_index do |set_payload, index|
          prescription = find_or_build_set_prescription(slot, set_payload)
          prescription.assign_attributes(set_prescription_attributes(set_payload, index))
          prescription.save!
          seen_set_ids << prescription.id
        end

        slot.set_prescriptions.where.not(id: seen_set_ids).destroy_all
      end

      def find_or_build_set_prescription(slot, set_payload)
        return slot.set_prescriptions.build if set_payload[:id].blank?

        slot.set_prescriptions.find(set_payload[:id])
      end

      def set_prescription_attributes(set_payload, index)
        set_payload.slice(
          :set_type,
          :rep_min,
          :rep_max,
          :load_strategy,
          :load_value
        ).merge(position: set_payload[:position].presence || index + 1)
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
