class CreateRoutineSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :routine_sessions, id: :uuid do |t|
      t.references :routine, foreign_key: { on_delete: :nullify }, type: :uuid
      t.string :routine_name, null: false
      t.string :status, null: false, default: "active"
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    create_table :routine_session_items, id: :uuid do |t|
      t.references :routine_session, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :routine_item, foreign_key: { on_delete: :nullify }, type: :uuid
      t.references :exercise, foreign_key: { on_delete: :nullify }, type: :uuid
      t.integer :position, null: false
      t.string :exercise_name, null: false
      t.string :target_mode, null: false
      t.integer :sets
      t.integer :target_reps
      t.integer :target_duration_seconds
      t.text :notes
      t.datetime :completed_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :routine_sessions, :status
    add_index :routine_sessions, :started_at
    add_index :routine_session_items, %i[routine_session_id position], unique: true

    add_check_constraint :routine_sessions, "routine_name <> ''", name: "routine_sessions_name_present"
    add_check_constraint :routine_sessions,
                         "status IN ('active', 'completed')",
                         name: "routine_sessions_status_valid"
    add_check_constraint :routine_sessions,
                         "(status = 'active' AND completed_at IS NULL) OR " \
                         "(status = 'completed' AND completed_at IS NOT NULL)",
                         name: "routine_sessions_completion_matches_status"
    add_check_constraint :routine_session_items,
                         "position > 0",
                         name: "routine_session_items_position_positive"
    add_check_constraint :routine_session_items,
                         "exercise_name <> ''",
                         name: "routine_session_items_exercise_name_present"
    add_check_constraint :routine_session_items,
                         "target_mode IN ('completion_only', 'reps', 'duration', 'load_optional')",
                         name: "routine_session_items_target_mode_valid"
    add_check_constraint :routine_session_items,
                         "sets IS NULL OR sets > 0",
                         name: "routine_session_items_sets_positive"
    add_check_constraint :routine_session_items,
                         "target_reps IS NULL OR target_reps > 0",
                         name: "routine_session_items_target_reps_positive"
    add_check_constraint :routine_session_items,
                         "target_duration_seconds IS NULL OR target_duration_seconds > 0",
                         name: "routine_session_items_target_duration_positive"
  end
end
