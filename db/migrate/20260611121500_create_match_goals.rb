class CreateMatchGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :match_goals do |t|
      t.references :match, null: false, foreign_key: true
      t.references :scoring_team, null: false, foreign_key: { to_table: :teams }
      t.references :scorer_team_player, null: false, foreign_key: { to_table: :team_players }
      t.references :assistant_team_player, foreign_key: { to_table: :team_players }
      t.datetime :scored_at, null: false
      t.datetime :undone_at
      t.integer :home_score_after, null: false, default: 0
      t.integer :away_score_after, null: false, default: 0

      t.timestamps
    end
  end
end
