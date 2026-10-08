module RoutineSessions
  class Start
    Result = Struct.new(:routine_session, :created, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(routine:, attributes:)
      @routine = routine
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      existing_session = RoutineSession.find_by(id: attributes[:id])
      return Result.new(routine_session: existing_session, created: false) if existing_session

      routine_session = RoutineSession.transaction { create_routine_session! }
      Result.new(routine_session:, created: true)
    rescue ActiveRecord::RecordNotUnique
      Result.new(routine_session: RoutineSession.find(attributes[:id]), created: false)
    end

    private

    attr_reader :routine, :attributes

    def create_routine_session!
      RoutineSession.create!(
        id: attributes[:id],
        routine:,
        routine_name: routine.name,
        started_at: attributes[:started_at]
      ).tap do |routine_session|
        routine.items.each do |routine_item|
          create_session_item!(routine_session, routine_item)
        end
      end
    end

    def create_session_item!(routine_session, routine_item)
      routine_session.items.create!(
        id: session_item_ids[routine_item.id.to_s],
        routine_item:,
        exercise: routine_item.exercise,
        position: routine_item.position,
        exercise_name: routine_item.exercise.name,
        target_mode: routine_item.target_mode,
        sets: routine_item.sets,
        target_reps: routine_item.target_reps,
        target_duration_seconds: routine_item.target_duration_seconds,
        notes: routine_item.notes_override
      )
    end

    def session_item_ids
      @session_item_ids ||= attributes.fetch(:items, []).each_with_object({}) do |item, ids|
        item = item.to_h.symbolize_keys
        next if item[:routine_item_id].blank? || item[:id].blank?

        ids[item[:routine_item_id].to_s] = item[:id]
      end
    end
  end
end
