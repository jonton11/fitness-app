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

    test "stores the calculated next target when a completed exercise clears its working sets" do
      template = create_progression_template(starting_load_value: 65, progression_increment: 5)
      option = template.slots.first.exercise_options.first
      session = Start.call(workout_template: template)
      perform_working_sets(session, [ 8, 8, 8 ])

      Complete.call(workout_session: session, attributes: { lock_version: session.lock_version })

      assert_equal BigDecimal("70"), option.reload.calculated_next_load_value
    end

    test "carries the current target when a completed exercise misses its working sets" do
      template = create_progression_template(starting_load_value: 65, progression_increment: 5)
      option = template.slots.first.exercise_options.first
      session = Start.call(workout_template: template)
      perform_working_sets(session, [ 8, 7, 6 ])

      Complete.call(workout_session: session, attributes: { lock_version: session.lock_version })

      assert_equal BigDecimal("65"), option.reload.calculated_next_load_value
    end

    test "preserves a manual next target while storing the calculated target" do
      template = create_progression_template(starting_load_value: 65, next_load_value: 90, progression_increment: 5)
      option = template.slots.first.exercise_options.first
      session = Start.call(workout_template: template)
      perform_working_sets(session, [ 8, 8, 8 ])

      Complete.call(workout_session: session, attributes: { lock_version: session.lock_version })
      next_session = Start.call(workout_template: template)

      assert_equal BigDecimal("90"), option.reload.next_load_value
      assert_equal BigDecimal("70"), option.calculated_next_load_value
      assert_equal BigDecimal("90"), next_session.exercises.first.planned_working_load_value
    end

    test "starts later sessions from the calculated next target" do
      template = create_progression_template(starting_load_value: 65, progression_increment: 5)
      session = Start.call(workout_template: template)
      perform_working_sets(session, [ 8, 8, 8 ])
      Complete.call(workout_session: session, attributes: { lock_version: session.lock_version })

      next_session = Start.call(workout_template: template)

      session_exercise = next_session.exercises.first
      assert_equal BigDecimal("70"), session_exercise.planned_working_load_value
      assert_equal [ BigDecimal("70"), BigDecimal("70"), BigDecimal("70") ],
                   session_exercise.workout_session_sets.map(&:planned_load_value)
    end

    test "keeps progression based on workout history when sessions complete out of order" do
      template = create_progression_template(starting_load_value: 65, progression_increment: 5)
      option = template.slots.first.exercise_options.first
      older_session = Start.call(
        workout_template: template,
        started_at: Time.zone.parse("2026-10-01 12:00:00")
      )
      newer_session = Start.call(
        workout_template: template,
        started_at: Time.zone.parse("2026-10-02 12:00:00")
      )
      perform_working_sets(older_session, [ 8, 8, 8 ])
      perform_working_sets(newer_session, [ 8, 7, 6 ])

      Complete.call(workout_session: newer_session, attributes: { lock_version: newer_session.lock_version })
      Complete.call(workout_session: older_session, attributes: { lock_version: older_session.lock_version })

      assert_equal BigDecimal("65"), option.reload.calculated_next_load_value
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

    def create_progression_template(starting_load_value:, progression_increment:, next_load_value: nil)
      template = WorkoutTemplate.create!(name: "Upper")
      exercise = Exercise.create!(
        name: "Incline Dumbbell Press",
        primary_muscle_group: "Chest",
        load_type: "lb"
      )
      slot = template.slots.create!(
        position: 1,
        label: "Upper Chest Press",
        default_exercise: exercise,
        rest_seconds: 180
      )
      slot.exercise_options.create!(
        position: 1,
        exercise:,
        is_default: true,
        starting_load_value:,
        next_load_value:,
        progression_increment:
      )
      3.times do |index|
        slot.set_prescriptions.create!(
          position: index + 1,
          set_type: "working",
          rep_min: 5,
          rep_max: 8,
          load_strategy: "working_load"
        )
      end
      template
    end

    def perform_working_sets(session, reps)
      completed_at = Time.zone.parse("2026-10-02 11:45:00")
      session.exercises.first.workout_session_sets.where(set_type: "working").zip(reps).each do |set, actual_reps|
        set.update!(
          actual_reps:,
          actual_load_value: set.planned_load_value,
          completion_state: "completed",
          completed_at:
        )
      end
    end
  end
end
