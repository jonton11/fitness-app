module WorkoutSuggestions
  class Calculate
    LOOKBACK = 90.days

    Result = Struct.new(:workout_template, :last_relevant_at, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(now: Time.current)
      @now = now
    end

    def call
      candidates.min_by do |candidate|
        [
          candidate.last_relevant_at.present? ? 1 : 0,
          candidate.last_relevant_at&.to_f || 0,
          candidate.workout_template.name.downcase,
          candidate.workout_template.id
        ]
      end
    end

    private

    attr_reader :now

    def candidates
      eligible_templates.map do |template|
        Result.new(
          workout_template: template,
          last_relevant_at: template.focus_tags.filter_map { |tag| recency_by_tag[normalize(tag)] }.max
        )
      end
    end

    def eligible_templates
      @eligible_templates ||= WorkoutTemplate
        .where(archived_at: nil)
        .where.not(focus_tags: [])
        .order(:name, :id)
        .to_a
    end

    def recency_by_tag
      @recency_by_tag ||= {}.tap do |recencies|
        completed_workouts.find_each do |session|
          record_recency(recencies, session.workout_template.focus_tags, session.completed_at)
        end

        recent_activities.find_each do |activity|
          record_recency(recencies, activity.focus_tags, activity.started_at)
        end
      end
    end

    def completed_workouts
      WorkoutSession
        .includes(:workout_template)
        .where(status: "completed", completed_at: lookback_range)
    end

    def recent_activities
      Activity.where(started_at: lookback_range).where.not(focus_tags: [])
    end

    def lookback_range
      (now - LOOKBACK)..now
    end

    def record_recency(recencies, tags, occurred_at)
      Array(tags).each do |tag|
        normalized_tag = normalize(tag)
        next if normalized_tag.blank?

        recencies[normalized_tag] = [ recencies[normalized_tag], occurred_at ].compact.max
      end
    end

    def normalize(tag)
      tag.to_s.strip.downcase
    end
  end
end
