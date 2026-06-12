FactoryBot.define do
  factory :player_rating_change do
    player
    season
    match_day { association :match_day, season: season }
    match { nil }
    rating_scope { PlayerRatingChange::RATING_SCOPE_SEASON }
    source_type { PlayerRatingChange::SOURCE_TYPE_MATCH }
    reason { "match_elo" }
    old_elo_score { 1000 }
    elo_delta { 16 }
    new_elo_score { 1016 }
    performance_delta { nil }
    elo_k_value { 16.0 }
    player_advantage_elo { 40.0 }
  end
end
