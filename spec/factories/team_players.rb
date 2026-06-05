FactoryBot.define do
  factory :team_player do
    association :team
    association :player
  end
end
