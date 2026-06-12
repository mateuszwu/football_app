class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :match_day, null: false, foreign_key: true
      t.references :team_setup, foreign_key: true
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.references :lineup_source_match, foreign_key: { to_table: :matches }
      t.string :lineup_source_type
      t.string :status, null: false, default: "pending"
      t.integer :home_score, null: false, default: 0
      t.integer :away_score, null: false, default: 0
      t.integer :timer_interval_seconds, null: false, default: 300
      t.integer :timer_beep_count, null: false, default: 3
      t.boolean :ranked, null: false, default: true
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :elo_processed_at
      t.datetime :performance_processed_at

      t.timestamps
    end

    add_index :matches, [ :match_day_id, :home_team_id, :away_team_id ], unique: true
  end
end
