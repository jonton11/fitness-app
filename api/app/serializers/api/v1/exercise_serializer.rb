module Api
  module V1
    class ExerciseSerializer < ApplicationSerializer
      def as_json
        {
          id: record.id,
          name: record.name,
          primary_muscle_group: record.primary_muscle_group,
          secondary_muscle_groups: record.secondary_muscle_groups,
          load_type: record.load_type,
          notes: record.notes,
          external_url: record.external_url,
          archived_at: serialize_time(record.archived_at),
          created_at: serialize_time(record.created_at),
          updated_at: serialize_time(record.updated_at),
          lock_version: record.lock_version
        }
      end
    end
  end
end
