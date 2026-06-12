class AddLifecycleFieldsToMatchesAndMatchGoals < ActiveRecord::Migration[8.1]
  def change
    change_table :matches do |t|
      t.references :team_setup, foreign_key: true
      t.string :lineup_source_type
      t.references :lineup_source_match, foreign_key: { to_table: :matches }
      t.string :status, null: false, default: "pending"
      t.integer :timer_interval_seconds, null: false, default: 300
      t.integer :timer_beep_count, null: false, default: 3
      t.boolean :ranked, null: false, default: true
      t.datetime :elo_processed_at
      t.datetime :performance_processed_at
    end

    add_column :match_goals, :undone_at, :datetime
  end
end
