class CreateRoutines < ActiveRecord::Migration[8.1]
  def change
    create_table :routines, id: :uuid do |t|
      t.string :name, null: false
      t.text :notes
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    create_table :routine_items, id: :uuid do |t|
      t.references :routine, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :exercise, null: false, foreign_key: true, type: :uuid
      t.integer :position, null: false
      t.string :target_mode, null: false
      t.integer :sets
      t.integer :target_reps
      t.integer :target_duration_seconds
      t.text :notes_override

      t.timestamps
    end

    add_index :routines, :archived_at
    add_index :routine_items, %i[routine_id position], unique: true

    add_check_constraint :routines, "name <> ''", name: "routines_name_present"
    add_check_constraint :routine_items, "position > 0", name: "routine_items_position_positive"
    add_check_constraint :routine_items,
                         "target_mode IN ('completion_only', 'reps', 'duration', 'load_optional')",
                         name: "routine_items_target_mode_valid"
    add_check_constraint :routine_items,
                         "sets IS NULL OR sets > 0",
                         name: "routine_items_sets_positive"
    add_check_constraint :routine_items,
                         "target_reps IS NULL OR target_reps > 0",
                         name: "routine_items_target_reps_positive"
    add_check_constraint :routine_items,
                         "target_duration_seconds IS NULL OR target_duration_seconds > 0",
                         name: "routine_items_target_duration_positive"
  end
end
