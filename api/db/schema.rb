# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_06_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "exercises", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "primary_muscle_group", null: false
    t.string "secondary_muscle_groups", default: [], null: false, array: true
    t.string "load_type", null: false
    t.text "notes"
    t.string "external_url"
    t.datetime "archived_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_exercises_on_archived_at"
    t.check_constraint "load_type::text = ANY (ARRAY['lb'::character varying, 'kg'::character varying, 'machine_stack'::character varying, 'plate_count'::character varying, 'bodyweight'::character varying, 'bodyweight_plus_added'::character varying, 'assisted'::character varying, 'none'::character varying]::text[])", name: "exercises_load_type_valid"
    t.check_constraint "name::text <> ''::text", name: "exercises_name_present"
    t.check_constraint "primary_muscle_group::text <> ''::text", name: "exercises_primary_muscle_group_present"
  end

  create_table "workout_session_exercises", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workout_session_id", null: false
    t.uuid "workout_template_slot_id"
    t.uuid "workout_template_exercise_option_id"
    t.uuid "selected_exercise_id", null: false
    t.integer "position", null: false
    t.string "label", null: false
    t.string "selected_exercise_name", null: false
    t.string "selected_exercise_load_type", null: false
    t.integer "rest_seconds", default: 180, null: false
    t.decimal "planned_working_load_value", precision: 10, scale: 2
    t.decimal "progression_increment", precision: 10, scale: 2
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.index ["selected_exercise_id"], name: "index_workout_session_exercises_on_selected_exercise_id"
    t.index ["workout_session_id", "position"], name: "index_session_exercises_on_session_and_position"
    t.index ["workout_session_id"], name: "index_workout_session_exercises_on_workout_session_id"
    t.index ["workout_template_exercise_option_id"], name: "idx_on_workout_template_exercise_option_id_8af7b4a1e9"
    t.index ["workout_template_slot_id"], name: "index_workout_session_exercises_on_workout_template_slot_id"
    t.check_constraint "\"position\" > 0", name: "workout_session_exercises_position_positive"
    t.check_constraint "label::text <> ''::text", name: "workout_session_exercises_label_present"
    t.check_constraint "planned_working_load_value IS NULL OR planned_working_load_value >= 0::numeric", name: "workout_session_exercises_planned_load_non_negative"
    t.check_constraint "progression_increment IS NULL OR progression_increment >= 0::numeric", name: "workout_session_exercises_increment_non_negative"
    t.check_constraint "rest_seconds >= 0", name: "workout_session_exercises_rest_seconds_non_negative"
    t.check_constraint "selected_exercise_load_type::text = ANY (ARRAY['lb'::character varying, 'kg'::character varying, 'machine_stack'::character varying, 'plate_count'::character varying, 'bodyweight'::character varying, 'bodyweight_plus_added'::character varying, 'assisted'::character varying, 'none'::character varying]::text[])", name: "workout_session_exercises_load_type_valid"
    t.check_constraint "selected_exercise_name::text <> ''::text", name: "workout_session_exercises_selected_name_present"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'completed'::character varying, 'skipped'::character varying]::text[])", name: "workout_session_exercises_status_valid"
  end

  create_table "workout_session_sets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workout_session_exercise_id", null: false
    t.uuid "workout_template_set_prescription_id"
    t.integer "position", null: false
    t.string "set_type", null: false
    t.integer "target_rep_min", null: false
    t.integer "target_rep_max", null: false
    t.string "load_strategy", null: false
    t.decimal "prescribed_load_value", precision: 10, scale: 2
    t.decimal "planned_load_value", precision: 10, scale: 2
    t.integer "actual_reps"
    t.decimal "actual_load_value", precision: 10, scale: 2
    t.string "completion_state", default: "pending", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.index ["workout_session_exercise_id", "position"], name: "index_session_sets_on_exercise_and_position"
    t.index ["workout_session_exercise_id"], name: "index_workout_session_sets_on_workout_session_exercise_id"
    t.index ["workout_template_set_prescription_id"], name: "idx_on_workout_template_set_prescription_id_7c1a64c39d"
    t.check_constraint "(completion_state::text = ANY (ARRAY['completed'::character varying, 'attempted_but_target_not_met'::character varying]::text[])) AND actual_reps IS NOT NULL AND completed_at IS NOT NULL OR (completion_state::text = ANY (ARRAY['pending'::character varying, 'not_performed'::character varying]::text[])) AND actual_reps IS NULL AND actual_load_value IS NULL AND completed_at IS NULL", name: "workout_session_sets_actuals_match_completion_state"
    t.check_constraint "\"position\" > 0", name: "workout_session_sets_position_positive"
    t.check_constraint "actual_load_value IS NULL OR actual_load_value >= 0::numeric", name: "workout_session_sets_actual_load_non_negative"
    t.check_constraint "actual_reps IS NULL OR actual_reps >= 0", name: "workout_session_sets_actual_reps_non_negative"
    t.check_constraint "completion_state::text = ANY (ARRAY['pending'::character varying, 'completed'::character varying, 'attempted_but_target_not_met'::character varying, 'not_performed'::character varying]::text[])", name: "workout_session_sets_completion_state_valid"
    t.check_constraint "load_strategy::text = ANY (ARRAY['working_load'::character varying, 'percentage_of_working_load'::character varying, 'explicit'::character varying, 'bodyweight'::character varying, 'none'::character varying]::text[])", name: "workout_session_sets_load_strategy_valid"
    t.check_constraint "planned_load_value IS NULL OR planned_load_value >= 0::numeric", name: "workout_session_sets_planned_load_non_negative"
    t.check_constraint "prescribed_load_value IS NULL OR prescribed_load_value >= 0::numeric", name: "workout_session_sets_prescribed_load_non_negative"
    t.check_constraint "set_type::text = ANY (ARRAY['warmup'::character varying, 'working'::character varying]::text[])", name: "workout_session_sets_type_valid"
    t.check_constraint "target_rep_max >= target_rep_min", name: "workout_session_sets_rep_range_valid"
    t.check_constraint "target_rep_min > 0", name: "workout_session_sets_rep_min_positive"
  end

  create_table "workout_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workout_template_id", null: false
    t.string "workout_template_name", null: false
    t.string "status", default: "active", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.datetime "canceled_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at"], name: "index_workout_sessions_on_started_at"
    t.index ["status"], name: "index_workout_sessions_on_status"
    t.index ["workout_template_id"], name: "index_workout_sessions_on_workout_template_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'completed'::character varying, 'canceled'::character varying]::text[])", name: "workout_sessions_status_valid"
    t.check_constraint "workout_template_name::text <> ''::text", name: "workout_sessions_template_name_present"
  end

  create_table "workout_template_exercise_options", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workout_template_slot_id", null: false
    t.uuid "exercise_id", null: false
    t.integer "position", null: false
    t.boolean "is_default", default: false, null: false
    t.decimal "starting_load_value", precision: 10, scale: 2
    t.decimal "next_load_value", precision: 10, scale: 2
    t.decimal "progression_increment", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "calculated_next_load_value", precision: 10, scale: 2
    t.index ["exercise_id"], name: "index_workout_template_exercise_options_on_exercise_id"
    t.index ["workout_template_slot_id", "exercise_id"], name: "index_template_options_on_slot_and_exercise", unique: true
    t.index ["workout_template_slot_id", "position"], name: "index_template_options_on_slot_and_position"
    t.index ["workout_template_slot_id"], name: "idx_on_workout_template_slot_id_915eabb622"
    t.check_constraint "\"position\" > 0", name: "workout_template_options_position_positive"
    t.check_constraint "calculated_next_load_value IS NULL OR calculated_next_load_value >= 0::numeric", name: "workout_template_options_calculated_next_load_non_negative"
    t.check_constraint "next_load_value IS NULL OR next_load_value >= 0::numeric", name: "workout_template_options_next_load_non_negative"
    t.check_constraint "progression_increment IS NULL OR progression_increment >= 0::numeric", name: "workout_template_options_increment_non_negative"
    t.check_constraint "starting_load_value IS NULL OR starting_load_value >= 0::numeric", name: "workout_template_options_starting_load_non_negative"
  end

  create_table "workout_template_set_prescriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workout_template_slot_id", null: false
    t.integer "position", null: false
    t.string "set_type", null: false
    t.integer "rep_min", null: false
    t.integer "rep_max", null: false
    t.string "load_strategy", null: false
    t.decimal "load_value", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workout_template_slot_id", "position"], name: "index_template_sets_on_slot_and_position"
    t.index ["workout_template_slot_id"], name: "idx_on_workout_template_slot_id_3c71d1db64"
    t.check_constraint "\"position\" > 0", name: "workout_template_sets_position_positive"
    t.check_constraint "load_strategy::text = ANY (ARRAY['working_load'::character varying, 'percentage_of_working_load'::character varying, 'explicit'::character varying, 'bodyweight'::character varying, 'none'::character varying]::text[])", name: "workout_template_sets_load_strategy_valid"
    t.check_constraint "load_value IS NULL OR load_value >= 0::numeric", name: "workout_template_sets_load_value_non_negative"
    t.check_constraint "rep_max >= rep_min", name: "workout_template_sets_rep_range_valid"
    t.check_constraint "rep_min > 0", name: "workout_template_sets_rep_min_positive"
    t.check_constraint "set_type::text = ANY (ARRAY['warmup'::character varying, 'working'::character varying]::text[])", name: "workout_template_sets_type_valid"
  end

  create_table "workout_template_slots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workout_template_id", null: false
    t.integer "position", null: false
    t.string "label", null: false
    t.uuid "default_exercise_id", null: false
    t.integer "rest_seconds", default: 180, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["default_exercise_id"], name: "index_workout_template_slots_on_default_exercise_id"
    t.index ["workout_template_id", "position"], name: "idx_on_workout_template_id_position_6b6cc2278a"
    t.index ["workout_template_id"], name: "index_workout_template_slots_on_workout_template_id"
    t.check_constraint "\"position\" > 0", name: "workout_template_slots_position_positive"
    t.check_constraint "label::text <> ''::text", name: "workout_template_slots_label_present"
    t.check_constraint "rest_seconds >= 0", name: "workout_template_slots_rest_seconds_non_negative"
  end

  create_table "workout_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.datetime "archived_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_workout_templates_on_archived_at"
    t.check_constraint "name::text <> ''::text", name: "workout_templates_name_present"
  end

  add_foreign_key "workout_session_exercises", "exercises", column: "selected_exercise_id"
  add_foreign_key "workout_session_exercises", "workout_sessions", on_delete: :cascade
  add_foreign_key "workout_session_exercises", "workout_template_exercise_options", on_delete: :nullify
  add_foreign_key "workout_session_exercises", "workout_template_slots", on_delete: :nullify
  add_foreign_key "workout_session_sets", "workout_session_exercises", on_delete: :cascade
  add_foreign_key "workout_session_sets", "workout_template_set_prescriptions", on_delete: :nullify
  add_foreign_key "workout_sessions", "workout_templates"
  add_foreign_key "workout_template_exercise_options", "exercises"
  add_foreign_key "workout_template_exercise_options", "workout_template_slots", on_delete: :cascade
  add_foreign_key "workout_template_set_prescriptions", "workout_template_slots", on_delete: :cascade
  add_foreign_key "workout_template_slots", "exercises", column: "default_exercise_id"
  add_foreign_key "workout_template_slots", "workout_templates", on_delete: :cascade
end
