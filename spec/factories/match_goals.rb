FactoryBot.define do
  factory :match_goal do
    association :match
    association :scoring_team, factory: :team
    association :scorer, factory: :player
    scored_at { Time.current }
  end
end
