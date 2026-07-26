class CreateSeasonPairStats < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :pair_stats_generated_at, :datetime

    create_table :season_pair_stats do |t|
      t.references :season, null: false, foreign_key: true
      t.references :player_one, null: false, foreign_key: { to_table: :players }
      t.references :player_two, null: false, foreign_key: { to_table: :players }
      t.integer :shared_match_days_count, null: false, default: 0
      t.integer :shared_matches_count, null: false, default: 0
      t.integer :wins, null: false, default: 0
      t.integer :draws, null: false, default: 0
      t.integer :losses, null: false, default: 0
      t.integer :goals, null: false, default: 0
      t.integer :assists, null: false, default: 0
      t.integer :mutual_assists, null: false, default: 0
      t.integer :goal_difference, null: false, default: 0

      t.timestamps
    end

    add_index :season_pair_stats,
      [ :season_id, :player_one_id, :player_two_id ],
      unique: true,
      name: "index_season_pair_stats_on_season_and_players"
    add_index :season_pair_stats, [ :season_id, :shared_matches_count ]
    add_check_constraint :season_pair_stats,
      "player_one_id < player_two_id",
      name: "season_pair_stats_players_ordered"
  end
end
