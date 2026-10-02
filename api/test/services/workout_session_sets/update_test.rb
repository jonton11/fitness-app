require "test_helper"

module WorkoutSessionSets
  class UpdateTest < ActiveSupport::TestCase
    test "marks a set completed and defaults load to planned load" do
      workout_session_set = create_workout_session_set(planned_load_value: 65)

      updated_set = Update.call(
        workout_session_set:,
        attributes: { actual_reps: 7 },
        completed_at: Time.zone.parse("2026-10-02 12:00:00")
      )

      assert_equal "completed", updated_set.completion_state
      assert_equal 7, updated_set.actual_reps
      assert_equal BigDecimal("65"), updated_set.actual_load_value
      assert_equal Time.zone.parse("2026-10-02 12:00:00"), updated_set.completed_at
    end

    test "keeps explicit load and attempted state" do
      workout_session_set = create_workout_session_set(planned_load_value: 65)

      updated_set = Update.call(
        workout_session_set:,
        attributes: {
          completion_state: "attempted_but_target_not_met",
          actual_reps: 3,
          actual_load_value: 60
        },
        completed_at: Time.zone.parse("2026-10-02 12:00:00")
      )

      assert_equal "attempted_but_target_not_met", updated_set.completion_state
      assert_equal 3, updated_set.actual_reps
      assert_equal BigDecimal("60"), updated_set.actual_load_value
      assert_equal Time.zone.parse("2026-10-02 12:00:00"), updated_set.completed_at
    end

    test "preserves omitted actual fields when updating a performed set" do
      completed_at = Time.zone.parse("2026-10-02 11:30:00")
      workout_session_set = create_workout_session_set(
        completion_state: "completed",
        actual_reps: 7,
        actual_load_value: 62.5,
        completed_at:
      )

      updated_set = Update.call(
        workout_session_set:,
        attributes: { actual_reps: 8 },
        completed_at: Time.zone.parse("2026-10-02 12:00:00")
      )

      assert_equal "completed", updated_set.completion_state
      assert_equal 8, updated_set.actual_reps
      assert_equal BigDecimal("62.5"), updated_set.actual_load_value
      assert_equal completed_at, updated_set.completed_at
    end

    test "clears actuals when set is not performed" do
      workout_session_set = create_workout_session_set(
        completion_state: "completed",
        actual_reps: 7,
        actual_load_value: 65,
        completed_at: Time.current
      )

      updated_set = Update.call(
        workout_session_set:,
        attributes: { completion_state: "not_performed" }
      )

      assert_equal "not_performed", updated_set.completion_state
      assert_nil updated_set.actual_reps
      assert_nil updated_set.actual_load_value
      assert_nil updated_set.completed_at
    end

    test "requires actual reps for performed set states" do
      workout_session_set = create_workout_session_set

      error = assert_raises(ActiveRecord::RecordInvalid) do
        Update.call(
          workout_session_set:,
          attributes: { completion_state: "completed" },
          completed_at: Time.zone.parse("2026-10-02 12:00:00")
        )
      end

      assert_includes error.record.errors[:actual_reps], "can't be blank"
    end

    private

    def create_workout_session_set(attributes = {})
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
      session_exercise = session.exercises.create!(
        selected_exercise: exercise,
        position: 1,
        label: "Upper Chest Press",
        selected_exercise_name: exercise.name,
        selected_exercise_load_type: exercise.load_type,
        rest_seconds: 180
      )
      session_exercise.workout_session_sets.create!(
        {
          position: 1,
          set_type: "working",
          target_rep_min: 5,
          target_rep_max: 8,
          load_strategy: "working_load",
          planned_load_value: 65
        }.merge(attributes)
      )
    end
  end
end
