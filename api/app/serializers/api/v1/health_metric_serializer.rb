module Api
  module V1
    class HealthMetricSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          kind: record.kind,
          value: serialize_decimal(record.value),
          unit: record.unit,
          started_at: serialize_time(record.started_at),
          ended_at: serialize_time(record.ended_at),
          source: record.source,
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at)
        }
      end
    end
  end
end
