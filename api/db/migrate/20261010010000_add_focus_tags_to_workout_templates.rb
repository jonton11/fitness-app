class AddFocusTagsToWorkoutTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :workout_templates, :focus_tags, :string, array: true, default: [], null: false
  end
end
