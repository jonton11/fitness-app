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

ActiveRecord::Schema[8.1].define(version: 2026_10_01_000000) do
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
end
