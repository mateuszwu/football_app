class AddPublicStatsPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :matches, [ :status, :match_day_id ], if_not_exists: true
    add_index :matches, [ :status, :home_team_id ], if_not_exists: true
    add_index :matches, [ :status, :away_team_id ], if_not_exists: true

    add_index :match_goals, [ :match_id, :undone_at ], if_not_exists: true
    add_index :match_goals, [ :match_id, :scoring_team_id, :undone_at ], if_not_exists: true
    add_index :match_goals, [ :match_id, :scorer_team_player_id, :undone_at ], if_not_exists: true
    add_index :match_goals, [ :match_id, :assistant_team_player_id, :undone_at ], if_not_exists: true
    add_index :match_goals, [ :own_goal, :undone_at ], if_not_exists: true

    add_index :player_rating_changes,
      [ :player_id, :season_id, :rating_scope, :source_type, :created_at ],
      name: "index_rating_changes_on_player_season_source_created",
      if_not_exists: true

    add_index :player_season_stats, [ :season_id, :elo ], if_not_exists: true
    add_index :player_season_stats, [ :season_id, :goals ], if_not_exists: true
    add_index :player_season_stats, [ :season_id, :assists ], if_not_exists: true
    add_index :player_season_stats, [ :season_id, :mvp_votes_count ], if_not_exists: true
    add_index :player_season_stats, [ :season_id, :def_votes_count ], if_not_exists: true

    add_index :players, [ :approval_status, :active, :name ], if_not_exists: true
    add_index :team_players, [ :player_id, :team_id ], if_not_exists: true
    add_index :teams, [ :team_type, :team_setup_id ], if_not_exists: true
    add_index :teams, [ :match_id, :team_type ], if_not_exists: true
  end
end
