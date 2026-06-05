FactoryBot.define do
  factory :team do
    sequence(:name) { |number| "Team #{number}" }
    association :team_setup
    team_type { "baseline" }
  end
end
