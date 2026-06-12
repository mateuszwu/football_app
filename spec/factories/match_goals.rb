FactoryBot.define do
  factory :match_goal do
    association :match
    association :scoring_team, factory: :team
    association :scorer_team_player, factory: :team_player
    scored_at { Time.current }
    home_score_after { 1 }
    away_score_after { 0 }
  end
end
