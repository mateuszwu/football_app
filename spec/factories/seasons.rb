FactoryBot.define do
  factory :season do
    sequence(:name) { |number| "Season #{number}" }
    starts_on { Date.new(2026, 1, 1) }
    ends_on { Date.new(2026, 12, 31) }
    status { Season::STATUS_ACTIVE }
    initial_elo { 1000 }
    elo_k_factor { 32 }
    mvp_vote_bonus { 10 }
    def_vote_bonus { 10 }
    elo_k_value { 16.0 }
    player_advantage_elo { 40.0 }
    season_elo_carryover_factor { 0.5 }
    goal_points { 1.0 }
    assist_points { 0.8 }
    mvp_max_points { 4.0 }
    def_max_points { 3.0 }
    voting_bonus_cap { 5.0 }
    expected_voters_count { 5 }
    elo_settings_locked { false }
  end
end
