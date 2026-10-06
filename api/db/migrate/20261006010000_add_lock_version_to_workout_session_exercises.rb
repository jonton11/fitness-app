class AddLockVersionToWorkoutSessionExercises < ActiveRecord::Migration[8.1]
  def change
    add_column :workout_session_exercises, :lock_version, :integer, default: 0, null: false
  end
end
