module Api
  module V1
    class HealthController < ApplicationController
      allow_unauthenticated_access

      def show
        if database_available?
          render json: { status: "ok" }
        else
          render json: { status: "unavailable" }, status: :service_unavailable
        end
      end

      private

      def database_available?
        ApplicationRecord.connection_pool.with_connection do |connection|
          connection.verify!
          true
        end
      rescue ActiveRecord::ActiveRecordError
        false
      end
    end
  end
end
