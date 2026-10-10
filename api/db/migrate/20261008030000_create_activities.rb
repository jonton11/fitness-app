class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities, id: :uuid do |t|
      t.string :kind, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.text :notes
      t.string :focus_tags, array: true, default: [], null: false
      t.string :source, null: false, default: "manual"

      t.timestamps
    end

    add_index :activities, :kind
    add_index :activities, :started_at
    add_check_constraint :activities,
                         "kind IN ('basketball', 'rest_day', 'recovery', 'other')",
                         name: "activities_kind_valid"
    add_check_constraint :activities,
                         "source IN ('manual')",
                         name: "activities_source_valid"
    add_check_constraint :activities,
                         "ended_at IS NULL OR ended_at >= started_at",
                         name: "activities_end_after_start"
  end
end
