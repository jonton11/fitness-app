module Api
  module V1
    class RoutineSessionSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          routine_id: record.routine_id,
          routine_name: record.routine_name,
          status: record.status,
          started_at: serialize_time(record.started_at),
          completed_at: serialize_time(record.completed_at),
          items: record.items.map { |item| RoutineSessionItemSerializer.new(item).as_json },
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at),
          lock_version: record.lock_version
        }
      end
    end
  end
end
