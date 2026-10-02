module Api
  module V1
    class ApplicationSerializer
      def initialize(record)
        @record = record
      end

      private

      attr_reader :record

      def serialize_time(value)
        value&.utc&.iso8601(3)
      end

      def serialize_decimal(value)
        value&.to_f
      end
    end
  end
end
