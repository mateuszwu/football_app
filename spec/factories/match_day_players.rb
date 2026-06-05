FactoryBot.define do
  factory :match_day_player do
    association :match_day
    association :player
  end
end
