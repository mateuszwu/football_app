FactoryBot.define do
  factory :match do
    association :match_day
    association :home_team, factory: :team
    association :away_team, factory: :team
    home_score { 0 }
    away_score { 0 }
    started_at { nil }
    finished_at { nil }
  end
end
