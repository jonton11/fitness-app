module Activities
  class Create
    Result = Struct.new(:activity, :created, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(attributes:)
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      existing_activity = Activity.find_by(id: attributes[:id]) if attributes[:id].present?
      return Result.new(activity: existing_activity, created: false) if existing_activity

      activity = Activity.create!(attributes.merge(source: "manual"))
      Result.new(activity:, created: true)
    rescue ActiveRecord::RecordNotUnique
      raise if attributes[:id].blank?

      Result.new(activity: Activity.find(attributes[:id]), created: false)
    end

    private

    attr_reader :attributes
  end
end
