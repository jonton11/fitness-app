require "test_helper"

module Progression
  class CalculateNextTargetTest < ActiveSupport::TestCase
    test "increments the target when every working set reaches the top of the rep range" do
      session_exercise = create_session_exercise(planned_working_load_value: 65, progression_increment: 5)
      create_set(session_exercise, position: 1, set_type: "warmup", target_rep_min: 4, target_rep_max: 6, planned_load_value: 30, actual_reps: 4)
      create_set(session_exercise, position: 2, actual_reps: 8)
      create_set(session_exercise, position: 3, actual_reps: 8)
      create_set(session_exercise, position: 4, actual_reps: 8)

      result = CalculateNextTarget.call(session_exercise:)

      assert result.cleared?
      assert_equal BigDecimal("70"), result.next_load_value
    end

    test "carries the target when any working set misses the top of the rep range" do
      session_exercise = create_session_exercise(planned_working_load_value: 65, progression_increment: 5)
      create_set(session_exercise, position: 1, actual_reps: 8)
      create_set(session_exercise, position: 2, actual_reps: 7)
      create_set(session_exercise, position: 3, actual_reps: 6)

      result = CalculateNextTarget.call(session_exercise:)

      assert_not result.cleared?
      assert_equal BigDecimal("65"), result.next_load_value
    end

    test "carries the target when the exercise was not performed" do
      session_exercise = create_session_exercise(planned_working_load_value: 65, progression_increment: 5)
      create_set(session_exercise, position: 1, completion_state: "not_performed")
      create_set(session_exercise, position: 2, completion_state: "not_performed")
      create_set(session_exercise, position: 3, completion_state: "not_performed")

      result = CalculateNextTarget.call(session_exercise:)

      assert_not result.cleared?
      assert_equal BigDecimal("65"), result.next_load_value
    end

    private

    def create_session_exercise(planned_working_load_value:, progression_increment:)
      template = WorkoutTemplate.create!(name: "Upper")
      exercise = Exercise.create!(
        name: "Incline Dumbbell Press",
        primary_muscle_group: "Chest",
        load_type: "lb"
      )
      session = WorkoutSession.create!(
        workout_template: template,
        workout_template_name: template.name,
        started_at: Time.current
      )
      session.exercises.create!(
        selected_exercise: exercise,
        position: 1,
        label: "Upper Chest Press",
        selected_exercise_name: exercise.name,
        selected_exercise_load_type: exercise.load_type,
        rest_seconds: 180,
        planned_working_load_value:,
        progression_increment:
      )
    end

    def create_set(session_exercise, attributes = {})
      actual_reps = attributes.fetch(:actual_reps, 8)
      completion_state = attributes.fetch(:completion_state, "completed")

      session_exercise.workout_session_sets.create!(
        {
          position: 1,
          set_type: "working",
          target_rep_min: 5,
          target_rep_max: 8,
          load_strategy: "working_load",
          planned_load_value: 65,
          actual_reps:,
          actual_load_value: 65,
          completion_state:,
          completed_at: Time.zone.parse("2026-10-02 12:00:00")
        }.merge(attributes).tap { |set_attributes| clear_actuals!(set_attributes) unless performed?(set_attributes[:completion_state]) }
      )
    end

    def clear_actuals!(set_attributes)
      set_attributes[:actual_reps] = nil
      set_attributes[:actual_load_value] = nil
      set_attributes[:completed_at] = nil
    end

    def performed?(completion_state)
      WorkoutSessionSet::PERFORMED_COMPLETION_STATES.include?(completion_state)
    end
  end
end
