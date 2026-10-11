module HealthMetrics
  class Ingest
    Result = Struct.new(:health_metrics, :created_count, :deleted_count, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(user:, records:, deleted_ids: [])
      @user = user
      @records = records
      @deleted_ids = deleted_ids
    end

    def call
      created_count = 0
      deleted_count = 0

      health_metrics = HealthMetric.transaction do
        deleted_count = user.health_metrics.where(id: deleted_ids).delete_all

        records.map do |attributes|
          health_metric = user.health_metrics.create_or_find_by!(id: attributes[:id]) do |record|
            record.assign_attributes(attributes.except(:id).merge(source: "healthkit"))
          end
          created_count += 1 if health_metric.previously_new_record?
          health_metric
        end
      end

      Result.new(health_metrics:, created_count:, deleted_count:)
    end

    private

    attr_reader :user, :records, :deleted_ids
  end
end
