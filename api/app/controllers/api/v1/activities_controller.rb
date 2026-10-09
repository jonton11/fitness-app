module Api
  module V1
    class ActivitiesController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

      def index
        activities = Activity.order(started_at: :desc, created_at: :desc)
        total = activities.count
        activities = activities.limit(limit).offset(offset)

        render_collection(
          :activities,
          activities,
          serializer: Api::V1::ActivitySerializer,
          meta: { limit:, offset:, total: }
        )
      end

      def show
        render_resource(:activity, activity, serializer: Api::V1::ActivitySerializer)
      end

      def create
        attributes = activity_attributes
        return if performed?

        result = Activities::Create.call(attributes:)
        render_resource(
          :activity,
          result.activity,
          serializer: Api::V1::ActivitySerializer,
          status: result.created ? :created : :ok
        )
      end

      private

      def activity
        @activity ||= Activity.find(params[:id])
      end

      def activity_payload
        @activity_payload ||= params.require(:activity).permit(
          :id,
          :kind,
          :started_at,
          :ended_at,
          :notes,
          focus_tags: []
        )
      end

      def activity_attributes
        attributes = activity_payload.except(:started_at, :ended_at).to_h.symbolize_keys
        attributes[:started_at] = parsed_time(activity_payload[:started_at], field: "started_at")
        return attributes if performed?

        if activity_payload.key?(:ended_at)
          attributes[:ended_at] = parsed_time(activity_payload[:ended_at], field: "ended_at")
        end

        attributes
      end

      def parsed_time(value, field:)
        return if value.blank?

        Time.iso8601(value)
      rescue ArgumentError
        render_api_error(
          field:,
          code: ERROR_CODE_INVALID,
          message: "#{field.humanize} must be a valid ISO-8601 timestamp",
          status: :unprocessable_content
        )
        nil
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
          message: "Activity not found",
          status: :not_found
        )
      end
    end
  end
end
