module Api
  module V1
    class ActivitySerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          kind: record.kind,
          started_at: serialize_time(record.started_at),
          ended_at: serialize_time(record.ended_at),
          notes: record.notes,
          focus_tags: record.focus_tags,
          source: record.source,
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at)
        }
      end
    end
  end
end
