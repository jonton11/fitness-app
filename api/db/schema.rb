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

ActiveRecord::Schema[8.1].define(version: 2026_10_01_010000) do
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
    t.index ["exercise_id"], name: "index_workout_template_exercise_options_on_exercise_id"
    t.index ["workout_template_slot_id", "exercise_id"], name: "index_template_options_on_slot_and_exercise", unique: true
    t.index ["workout_template_slot_id", "position"], name: "index_template_options_on_slot_and_position"
    t.index ["workout_template_slot_id"], name: "idx_on_workout_template_slot_id_915eabb622"
    t.check_constraint "\"position\" > 0", name: "workout_template_options_position_positive"
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

  add_foreign_key "workout_template_exercise_options", "exercises"
  add_foreign_key "workout_template_exercise_options", "workout_template_slots", on_delete: :cascade
  add_foreign_key "workout_template_set_prescriptions", "workout_template_slots", on_delete: :cascade
  add_foreign_key "workout_template_slots", "exercises", column: "default_exercise_id"
  add_foreign_key "workout_template_slots", "workout_templates", on_delete: :cascade
end
