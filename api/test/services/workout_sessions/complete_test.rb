require "test_helper"

module WorkoutSessions
  class CompleteTest < ActiveSupport::TestCase
    test "finishes a session while preserving performed sets and marking pending work not performed" do
      session = create_workout_session
      performed_set, pending_set = session.exercises.first.workout_session_sets.to_a
      skipped_set = session.exercises.second.workout_session_sets.first
      performed_set.update!(
        actual_reps: 7,
        actual_load_value: 65,
        completion_state: "completed",
        completed_at: Time.zone.parse("2026-10-02 11:45:00")
      )

      completed_session = Complete.call(
        workout_session: session,
        attributes: { lock_version: session.lock_version },
        completed_at: Time.zone.parse("2026-10-02 12:00:00")
      )

      assert_equal "completed", completed_session.status
      assert_equal Time.zone.parse("2026-10-02 12:00:00"), completed_session.completed_at
      assert_nil completed_session.canceled_at

      assert_equal "completed", performed_set.reload.completion_state
      assert_equal 7, performed_set.actual_reps
      assert_equal BigDecimal("65"), performed_set.actual_load_value

      assert_equal "not_performed", pending_set.reload.completion_state
      assert_nil pending_set.actual_reps
      assert_nil pending_set.actual_load_value
      assert_nil pending_set.completed_at

      assert_equal "not_performed", skipped_set.reload.completion_state
      assert_equal "completed", session.exercises.first.reload.status
      assert_equal "skipped", session.exercises.second.reload.status
    end

    private

    def create_workout_session
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
      first_exercise = session.exercises.create!(
        selected_exercise: exercise,
        position: 1,
        label: "Upper Chest Press",
        selected_exercise_name: exercise.name,
        selected_exercise_load_type: exercise.load_type,
        rest_seconds: 180
      )
      first_exercise.workout_session_sets.create!(
        position: 1,
        set_type: "working",
        target_rep_min: 5,
        target_rep_max: 8,
        load_strategy: "working_load",
        planned_load_value: 65
      )
      first_exercise.workout_session_sets.create!(
        position: 2,
        set_type: "working",
        target_rep_min: 5,
        target_rep_max: 8,
        load_strategy: "working_load",
        planned_load_value: 65
      )
      second_exercise = session.exercises.create!(
        selected_exercise: exercise,
        position: 2,
        label: "Rows",
        selected_exercise_name: exercise.name,
        selected_exercise_load_type: exercise.load_type,
        rest_seconds: 180
      )
      second_exercise.workout_session_sets.create!(
        position: 1,
        set_type: "working",
        target_rep_min: 5,
        target_rep_max: 8,
        load_strategy: "working_load",
        planned_load_value: 65
      )

      session
    end
  end
end
