class CreateWorkoutTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_templates, id: :uuid do |t|
      t.string :name, null: false
      t.text :notes
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    create_table :workout_template_slots, id: :uuid do |t|
      t.references :workout_template, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.integer :position, null: false
      t.string :label, null: false
      t.references :default_exercise, null: false, foreign_key: { to_table: :exercises }, type: :uuid
      t.integer :rest_seconds, null: false, default: 180
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    create_table :workout_template_exercise_options, id: :uuid do |t|
      t.references :workout_template_slot, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :exercise, null: false, foreign_key: true, type: :uuid
      t.integer :position, null: false
      t.boolean :is_default, null: false, default: false
      t.decimal :starting_load_value, precision: 10, scale: 2
      t.decimal :next_load_value, precision: 10, scale: 2
      t.decimal :progression_increment, precision: 10, scale: 2

      t.timestamps
    end

    create_table :workout_template_set_prescriptions, id: :uuid do |t|
      t.references :workout_template_slot, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.integer :position, null: false
      t.string :set_type, null: false
      t.integer :rep_min, null: false
      t.integer :rep_max, null: false
      t.string :load_strategy, null: false
      t.decimal :load_value, precision: 10, scale: 2

      t.timestamps
    end

    add_index :workout_templates, :archived_at
    add_index :workout_template_slots, %i[workout_template_id position]
    add_index :workout_template_exercise_options,
              %i[workout_template_slot_id exercise_id],
              unique: true,
              name: "index_template_options_on_slot_and_exercise"
    add_index :workout_template_exercise_options,
              %i[workout_template_slot_id position],
              name: "index_template_options_on_slot_and_position"
    add_index :workout_template_set_prescriptions,
              %i[workout_template_slot_id position],
              name: "index_template_sets_on_slot_and_position"

    add_check_constraint :workout_templates, "name <> ''", name: "workout_templates_name_present"
    add_check_constraint :workout_template_slots, "position > 0", name: "workout_template_slots_position_positive"
    add_check_constraint :workout_template_slots, "label <> ''", name: "workout_template_slots_label_present"
    add_check_constraint :workout_template_slots, "rest_seconds >= 0", name: "workout_template_slots_rest_seconds_non_negative"
    add_check_constraint :workout_template_exercise_options, "position > 0", name: "workout_template_options_position_positive"
    add_check_constraint :workout_template_exercise_options,
                         "starting_load_value IS NULL OR starting_load_value >= 0",
                         name: "workout_template_options_starting_load_non_negative"
    add_check_constraint :workout_template_exercise_options,
                         "next_load_value IS NULL OR next_load_value >= 0",
                         name: "workout_template_options_next_load_non_negative"
    add_check_constraint :workout_template_exercise_options,
                         "progression_increment IS NULL OR progression_increment >= 0",
                         name: "workout_template_options_increment_non_negative"
    add_check_constraint :workout_template_set_prescriptions, "position > 0", name: "workout_template_sets_position_positive"
    add_check_constraint :workout_template_set_prescriptions, "rep_min > 0", name: "workout_template_sets_rep_min_positive"
    add_check_constraint :workout_template_set_prescriptions, "rep_max >= rep_min", name: "workout_template_sets_rep_range_valid"
    add_check_constraint :workout_template_set_prescriptions,
                         "set_type IN ('warmup', 'working')",
                         name: "workout_template_sets_type_valid"
    add_check_constraint :workout_template_set_prescriptions,
                         "load_strategy IN ('working_load', 'percentage_of_working_load', 'explicit', 'bodyweight', 'none')",
                         name: "workout_template_sets_load_strategy_valid"
    add_check_constraint :workout_template_set_prescriptions,
                         "load_value IS NULL OR load_value >= 0",
                         name: "workout_template_sets_load_value_non_negative"
  end
end
