class CreateExercises < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :exercises, id: :uuid do |t|
      t.string :name, null: false
      t.string :primary_muscle_group, null: false
      t.string :secondary_muscle_groups, array: true, null: false, default: []
      t.string :load_type, null: false
      t.text :notes
      t.string :external_url
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :exercises, :archived_at
    add_check_constraint :exercises, "name <> ''", name: "exercises_name_present"
    add_check_constraint :exercises, "primary_muscle_group <> ''", name: "exercises_primary_muscle_group_present"
    add_check_constraint :exercises, "load_type IN ('lb', 'kg', 'machine_stack', 'plate_count', 'bodyweight', 'bodyweight_plus_added', 'assisted', 'none')", name: "exercises_load_type_valid"
  end
end
