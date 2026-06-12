FactoryBot.define do
  factory :team do
    sequence(:name) { |number| "Team #{number}" }
    association :team_setup
    team_type { Team::TEAM_TYPE_BASELINE }
    lineup_source { Team::LINEUP_SOURCE_MANUAL }
  end
end
