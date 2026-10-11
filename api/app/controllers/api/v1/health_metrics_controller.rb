module Api
  module V1
    class HealthMetricsController < ApplicationController
      MAX_BATCH_SIZE = 500
      UUID_FORMAT = /\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/i

      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

      def index
        health_metrics = Current.user.health_metrics.order(ended_at: :desc, created_at: :desc)
        health_metrics = health_metrics.where(kind: params[:kind]) if params[:kind].present?
        total = health_metrics.count
        health_metrics = health_metrics.limit(limit).offset(offset)

        render_collection(
          :health_metrics,
          health_metrics,
          serializer: Api::V1::HealthMetricSerializer,
          meta: { limit:, offset:, total: }
        )
      end

      def create
        changes = health_metric_changes
        return if performed?

        result = HealthMetrics::Ingest.call(
          user: Current.user,
          records: changes.fetch(:records),
          deleted_ids: changes.fetch(:deleted_ids)
        )
        render_collection(
          :health_metrics,
          result.health_metrics,
          serializer: Api::V1::HealthMetricSerializer,
          meta: {
            created: result.created_count,
            replayed: result.health_metrics.size - result.created_count,
            deleted: result.deleted_count
          },
          status: result.created_count.positive? ? :created : :ok
        )
      end

      private

      def health_metric_changes
        payloads = params.fetch(:health_metrics, [])
        deleted_ids = params.fetch(:deleted_health_metric_ids, [])
        unless valid_batch_payload?(payloads, deleted_ids)
          render_api_error(
            field: "health_metrics",
            code: ERROR_CODE_INVALID,
            message: "Health metric changes must contain between 1 and #{MAX_BATCH_SIZE} records",
            status: :unprocessable_content
          )
          return
        end

        records = payloads.each_with_index.map do |payload, index|
          attributes = payload.permit(:id, :kind, :value, :unit, :started_at, :ended_at).to_h.symbolize_keys
          attributes[:started_at] = parsed_time(attributes[:started_at], field: "health_metrics[#{index}].started_at")
          return if performed?

          attributes[:ended_at] = parsed_time(attributes[:ended_at], field: "health_metrics[#{index}].ended_at")
          return if performed?

          attributes
        end

        { records:, deleted_ids: }
      end

      def valid_batch_payload?(payloads, deleted_ids)
        payloads.is_a?(Array) &&
          deleted_ids.is_a?(Array) &&
          (payloads.size + deleted_ids.size).between?(1, MAX_BATCH_SIZE) &&
          payloads.all? { |payload| payload.respond_to?(:permit) } &&
          deleted_ids.all? { |id| id.to_s.match?(UUID_FORMAT) }
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
        params.fetch(:limit, 100).to_i.clamp(1, 500)
      end

      def offset
        [ params.fetch(:offset, 0).to_i, 0 ].max
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end
    end
  end
end
