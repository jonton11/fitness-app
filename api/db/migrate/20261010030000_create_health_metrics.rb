class CreateHealthMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :health_metrics, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :kind, null: false
      t.decimal :value, null: false, precision: 14, scale: 4
      t.string :unit, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at, null: false
      t.string :source, null: false, default: "healthkit"

      t.timestamps
    end

    add_index :health_metrics, %i[user_id ended_at]
    add_index :health_metrics, %i[user_id kind ended_at]
    add_check_constraint :health_metrics,
                         "kind IN ('body_weight', 'body_fat_percentage', 'steps', 'active_energy', 'sleep_duration', 'resting_heart_rate')",
                         name: "health_metrics_kind_valid"
    add_check_constraint :health_metrics,
                         "(kind = 'body_weight' AND unit = 'kg') OR " \
                           "(kind = 'body_fat_percentage' AND unit = 'percent') OR " \
                           "(kind = 'steps' AND unit = 'count') OR " \
                           "(kind = 'active_energy' AND unit = 'kcal') OR " \
                           "(kind = 'sleep_duration' AND unit = 'minutes') OR " \
                           "(kind = 'resting_heart_rate' AND unit = 'bpm')",
                         name: "health_metrics_kind_unit_valid"
    add_check_constraint :health_metrics,
                         "source IN ('healthkit')",
                         name: "health_metrics_source_valid"
    add_check_constraint :health_metrics,
                         "value >= 0",
                         name: "health_metrics_value_nonnegative"
    add_check_constraint :health_metrics,
                         "ended_at >= started_at",
                         name: "health_metrics_end_after_start"
  end
end
