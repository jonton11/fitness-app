class AddStatusAndCompletedAtIndexToWorkoutSessions < ActiveRecord::Migration[8.1]
  def change
    add_index :workout_sessions, %i[status completed_at]
  end
end
