FactoryBot.define do
  factory :match_player_change do
    association :match
    association :player
    association :from_team, factory: :team
    association :to_team, factory: :team
    event_type { MatchPlayerChange::EVENT_TEAM_CHANGE }
    occurred_at { Time.current }
  end
end
