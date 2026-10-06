class AddCalculatedNextLoadToWorkoutTemplateExerciseOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :workout_template_exercise_options, :calculated_next_load_value, :decimal, precision: 10, scale: 2
    add_check_constraint :workout_template_exercise_options,
                         "calculated_next_load_value IS NULL OR calculated_next_load_value >= 0",
                         name: "workout_template_options_calculated_next_load_non_negative"
  end
end
