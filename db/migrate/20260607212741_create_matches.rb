class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :match_day, null: false, foreign_key: true
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.integer :home_score, null: false, default: 0
      t.integer :away_score, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :matches, [ :match_day_id, :home_team_id, :away_team_id ], unique: true
  end
end
