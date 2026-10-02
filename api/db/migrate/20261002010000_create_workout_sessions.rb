class CreateWorkoutSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_sessions, id: :uuid do |t|
      t.references :workout_template, null: false, foreign_key: true, type: :uuid
      t.string :workout_template_name, null: false
      t.string :status, null: false, default: "active"
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.datetime :canceled_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    create_table :workout_session_exercises, id: :uuid do |t|
      t.references :workout_session, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :workout_template_slot, foreign_key: { on_delete: :nullify }, type: :uuid
      t.references :workout_template_exercise_option, foreign_key: { on_delete: :nullify }, type: :uuid
      t.references :selected_exercise, null: false, foreign_key: { to_table: :exercises }, type: :uuid
      t.integer :position, null: false
      t.string :label, null: false
      t.string :selected_exercise_name, null: false
      t.string :selected_exercise_load_type, null: false
      t.integer :rest_seconds, null: false, default: 180
      t.decimal :planned_working_load_value, precision: 10, scale: 2
      t.decimal :progression_increment, precision: 10, scale: 2
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    create_table :workout_session_set_results, id: :uuid do |t|
      t.references :workout_session_exercise, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :workout_template_set_prescription, foreign_key: { on_delete: :nullify }, type: :uuid
      t.integer :position, null: false
      t.string :set_type, null: false
      t.integer :target_rep_min, null: false
      t.integer :target_rep_max, null: false
      t.string :load_strategy, null: false
      t.decimal :prescribed_load_value, precision: 10, scale: 2
      t.decimal :planned_load_value, precision: 10, scale: 2
      t.integer :actual_reps
      t.decimal :actual_load_value, precision: 10, scale: 2
      t.string :completion_state, null: false, default: "pending"
      t.datetime :completed_at

      t.timestamps
    end

    add_index :workout_sessions, :status
    add_index :workout_sessions, :started_at
    add_index :workout_session_exercises, %i[workout_session_id position], name: "index_session_exercises_on_session_and_position"
    add_index :workout_session_set_results,
              %i[workout_session_exercise_id position],
              name: "index_session_set_results_on_exercise_and_position"

    add_check_constraint :workout_sessions, "workout_template_name <> ''", name: "workout_sessions_template_name_present"
    add_check_constraint :workout_sessions,
                         "status IN ('active', 'completed', 'canceled')",
                         name: "workout_sessions_status_valid"
    add_check_constraint :workout_session_exercises, "position > 0", name: "workout_session_exercises_position_positive"
    add_check_constraint :workout_session_exercises, "label <> ''", name: "workout_session_exercises_label_present"
    add_check_constraint :workout_session_exercises,
                         "selected_exercise_name <> ''",
                         name: "workout_session_exercises_selected_name_present"
    add_check_constraint :workout_session_exercises,
                         "selected_exercise_load_type IN ('lb', 'kg', 'machine_stack', 'plate_count', 'bodyweight', 'bodyweight_plus_added', 'assisted', 'none')",
                         name: "workout_session_exercises_load_type_valid"
    add_check_constraint :workout_session_exercises,
                         "rest_seconds >= 0",
                         name: "workout_session_exercises_rest_seconds_non_negative"
    add_check_constraint :workout_session_exercises,
                         "planned_working_load_value IS NULL OR planned_working_load_value >= 0",
                         name: "workout_session_exercises_planned_load_non_negative"
    add_check_constraint :workout_session_exercises,
                         "progression_increment IS NULL OR progression_increment >= 0",
                         name: "workout_session_exercises_increment_non_negative"
    add_check_constraint :workout_session_exercises,
                         "status IN ('pending', 'completed', 'skipped')",
                         name: "workout_session_exercises_status_valid"
    add_check_constraint :workout_session_set_results,
                         "position > 0",
                         name: "workout_session_set_results_position_positive"
    add_check_constraint :workout_session_set_results,
                         "set_type IN ('warmup', 'working')",
                         name: "workout_session_set_results_type_valid"
    add_check_constraint :workout_session_set_results,
                         "target_rep_min > 0",
                         name: "workout_session_set_results_rep_min_positive"
    add_check_constraint :workout_session_set_results,
                         "target_rep_max >= target_rep_min",
                         name: "workout_session_set_results_rep_range_valid"
    add_check_constraint :workout_session_set_results,
                         "load_strategy IN ('working_load', 'percentage_of_working_load', 'explicit', 'bodyweight', 'none')",
                         name: "workout_session_set_results_load_strategy_valid"
    add_check_constraint :workout_session_set_results,
                         "prescribed_load_value IS NULL OR prescribed_load_value >= 0",
                         name: "workout_session_set_results_prescribed_load_non_negative"
    add_check_constraint :workout_session_set_results,
                         "planned_load_value IS NULL OR planned_load_value >= 0",
                         name: "workout_session_set_results_planned_load_non_negative"
    add_check_constraint :workout_session_set_results,
                         "actual_reps IS NULL OR actual_reps >= 0",
                         name: "workout_session_set_results_actual_reps_non_negative"
    add_check_constraint :workout_session_set_results,
                         "actual_load_value IS NULL OR actual_load_value >= 0",
                         name: "workout_session_set_results_actual_load_non_negative"
    add_check_constraint :workout_session_set_results,
                         "completion_state IN ('pending', 'completed', 'attempted_but_target_not_met', 'not_performed')",
                         name: "workout_session_set_results_completion_state_valid"
  end
end
