require "test_helper"

class WorkoutSessionTest < ActiveSupport::TestCase
  test "starts a workout session by snapshotting template prescriptions" do
    template = create_template

    assert_difference -> { WorkoutSession.count }, 1 do
      assert_difference -> { WorkoutSessionExercise.count }, 1 do
        assert_difference -> { WorkoutSessionSet.count }, 2 do
          WorkoutSessions::Start.call(workout_template: template, started_at: Time.zone.parse("2026-10-02 12:00:00"))
        end
      end
    end

    session = WorkoutSession.last
    assert_equal template, session.workout_template
    assert_equal "Upper Body", session.workout_template_name
    assert_equal "active", session.status
    assert_equal Time.zone.parse("2026-10-02 12:00:00"), session.started_at

    session_exercise = session.exercises.first
    assert_equal "Upper Chest Press", session_exercise.label
    assert_equal incline_press, session_exercise.selected_exercise
    assert_equal "Incline Dumbbell Press", session_exercise.selected_exercise_name
    assert_equal "lb", session_exercise.selected_exercise_load_type
    assert_equal 180, session_exercise.rest_seconds
    assert_equal BigDecimal("60"), session_exercise.planned_working_load_value
    assert_equal BigDecimal("5"), session_exercise.progression_increment
    assert_equal "pending", session_exercise.status

    warmup, working = session_exercise.workout_session_sets.to_a
    assert_equal "warmup", warmup.set_type
    assert_equal 4, warmup.target_rep_min
    assert_equal 6, warmup.target_rep_max
    assert_equal "percentage_of_working_load", warmup.load_strategy
    assert_equal BigDecimal("50"), warmup.prescribed_load_value
    assert_equal BigDecimal("30"), warmup.planned_load_value
    assert_equal "pending", warmup.completion_state

    assert_equal "working", working.set_type
    assert_equal BigDecimal("60"), working.planned_load_value
  end

  test "keeps session snapshot stable after template and exercise edits" do
    template = create_template
    session = WorkoutSessions::Start.call(workout_template: template)
    session_exercise = session.exercises.first
    warmup = session_exercise.workout_session_sets.first

    template.update!(name: "Renamed Upper")
    template.slots.first.update!(label: "Changed Slot", rest_seconds: 90)
    template.slots.first.exercise_options.first.update!(starting_load_value: 80, progression_increment: 10)
    template.slots.first.set_prescriptions.first.update!(rep_min: 8, rep_max: 10, load_value: 75)
    incline_press.update!(name: "Renamed Press", load_type: "kg")

    session.reload
    session_exercise.reload
    warmup.reload

    assert_equal "Upper Body", session.workout_template_name
    assert_equal "Upper Chest Press", session_exercise.label
    assert_equal 180, session_exercise.rest_seconds
    assert_equal BigDecimal("60"), session_exercise.planned_working_load_value
    assert_equal BigDecimal("5"), session_exercise.progression_increment
    assert_equal "Incline Dumbbell Press", session_exercise.selected_exercise_name
    assert_equal "lb", session_exercise.selected_exercise_load_type
    assert_equal 4, warmup.target_rep_min
    assert_equal 6, warmup.target_rep_max
    assert_equal BigDecimal("50"), warmup.prescribed_load_value
  end

  test "allows template slot details to be removed after a session starts" do
    template = create_template
    session = WorkoutSessions::Start.call(workout_template: template)
    session_exercise = session.exercises.first
    workout_session_set = session_exercise.workout_session_sets.first

    template.slots.first.destroy!

    session_exercise.reload
    workout_session_set.reload

    assert_nil session_exercise.workout_template_slot
    assert_nil session_exercise.workout_template_exercise_option
    assert_nil workout_session_set.workout_template_set_prescription
    assert_equal "Upper Chest Press", session_exercise.label
    assert_equal "warmup", workout_session_set.set_type
  end

  test "database enforces workout session set actual fields matching completion state" do
    session = WorkoutSessions::Start.call(workout_template: create_template)
    workout_session_set = session.exercises.first.workout_session_sets.first

    error = assert_raises(ActiveRecord::StatementInvalid) do
      WorkoutSessionSet.transaction(requires_new: true) do
        WorkoutSessionSet.where(id: workout_session_set.id).update_all(actual_reps: 4)
      end
    end

    assert_match "workout_session_sets_actuals_match_completion_state", error.message
  end

  test "validates workout session snapshot fields" do
    session = WorkoutSession.new(
      workout_template: create_template,
      workout_template_name: " ",
      status: "paused"
    )
    session_exercise = WorkoutSessionExercise.new(
      workout_session: session,
      selected_exercise: incline_press,
      position: 0,
      label: " ",
      selected_exercise_name: " ",
      selected_exercise_load_type: "stone",
      rest_seconds: -1,
      planned_working_load_value: -5,
      progression_increment: -2.5,
      status: "done"
    )
    workout_session_set = WorkoutSessionSet.new(
      workout_session_exercise: session_exercise,
      position: 0,
      set_type: "drop",
      target_rep_min: 8,
      target_rep_max: 5,
      load_strategy: "guess",
      prescribed_load_value: -1,
      planned_load_value: -1,
      actual_reps: -1,
      actual_load_value: -1,
      completion_state: "zeroed"
    )

    assert_not session.valid?
    assert_includes session.errors[:workout_template_name], "can't be blank"
    assert_includes session.errors[:status], "is not included in the list"
    assert_includes session.errors[:started_at], "can't be blank"

    assert_not session_exercise.valid?
    assert_includes session_exercise.errors[:position], "must be greater than 0"
    assert_includes session_exercise.errors[:label], "can't be blank"
    assert_includes session_exercise.errors[:selected_exercise_name], "can't be blank"
    assert_includes session_exercise.errors[:selected_exercise_load_type], "is not included in the list"
    assert_includes session_exercise.errors[:rest_seconds], "must be greater than or equal to 0"
    assert_includes session_exercise.errors[:planned_working_load_value], "must be greater than or equal to 0"
    assert_includes session_exercise.errors[:progression_increment], "must be greater than or equal to 0"
    assert_includes session_exercise.errors[:status], "is not included in the list"

    assert_not workout_session_set.valid?
    assert_includes workout_session_set.errors[:position], "must be greater than 0"
    assert_includes workout_session_set.errors[:set_type], "is not included in the list"
    assert_includes workout_session_set.errors[:target_rep_max], "must be greater than or equal to target rep min"
    assert_includes workout_session_set.errors[:load_strategy], "is not included in the list"
    assert_includes workout_session_set.errors[:prescribed_load_value], "must be greater than or equal to 0"
    assert_includes workout_session_set.errors[:planned_load_value], "must be greater than or equal to 0"
    assert_includes workout_session_set.errors[:actual_reps], "must be greater than or equal to 0"
    assert_includes workout_session_set.errors[:actual_load_value], "must be greater than or equal to 0"
    assert_includes workout_session_set.errors[:completion_state], "is not included in the list"
  end

  private

  def create_template
    template = WorkoutTemplate.create!(name: "Upper Body")
    slot = template.slots.create!(
      position: 1,
      label: "Upper Chest Press",
      default_exercise: incline_press,
      rest_seconds: 180
    )
    slot.exercise_options.create!(
      position: 1,
      exercise: incline_press,
      is_default: true,
      starting_load_value: 60,
      next_load_value: 65,
      progression_increment: 5
    )
    slot.set_prescriptions.create!(
      position: 1,
      set_type: "warmup",
      rep_min: 4,
      rep_max: 6,
      load_strategy: "percentage_of_working_load",
      load_value: 50
    )
    slot.set_prescriptions.create!(
      position: 2,
      set_type: "working",
      rep_min: 5,
      rep_max: 8,
      load_strategy: "working_load"
    )
    template
  end

  def incline_press
    @incline_press ||= Exercise.create!(
      name: "Incline Dumbbell Press",
      primary_muscle_group: "Chest",
      load_type: "lb"
    )
  end
end
