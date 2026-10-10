module Api
  module V1
    class RoutineSessionItemsController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::StaleObjectError, with: :render_conflict

      def update
        unless item_payload.key?(:completed)
          render_api_error(
            field: "completed",
            code: ERROR_CODE_INVALID,
            message: "Completed is required",
            status: :unprocessable_content
          )
          return
        end

        attributes = item_payload.slice(:completed, :lock_version)
        attributes[:completed_at] = parsed_completed_at if item_payload.key?(:completed_at)
        return if performed?

        item = RoutineSessionItems::Update.call(
          routine_session_item:,
          attributes:
        )

        render_resource(
          :routine_session_item,
          item,
          serializer: Api::V1::RoutineSessionItemSerializer
        )
      end

      private

      def routine_session_item
        @routine_session_item ||= RoutineSessionItem.includes(:routine_session).find(params[:id])
      end

      def item_payload
        @item_payload ||= params.require(:routine_session_item).permit(
          :completed,
          :completed_at,
          :lock_version
        )
      end

      def parsed_completed_at
        return if item_payload[:completed_at].blank?

        Time.iso8601(item_payload[:completed_at])
      rescue ArgumentError
        render_api_error(
          field: "completed_at",
          code: ERROR_CODE_INVALID,
          message: "Completed at must be a valid ISO-8601 timestamp",
          status: :unprocessable_content
        )
        nil
      end

      def render_record_invalid(error)
        render_validation_errors(error.record)
      end

      def render_not_found
        render_api_error(
          field: "id",
          code: ERROR_CODE_NOT_FOUND,
          message: "Routine session item not found",
          status: :not_found
        )
      end

      def render_conflict
        render_api_error(
          field: "lock_version",
          code: ERROR_CODE_STALE,
          message: "Routine session item has been changed by another request",
          status: :conflict
        )
      end
    end
  end
end
