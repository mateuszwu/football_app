FactoryBot.define do
  factory :match_day do
    association :season
    played_on { Date.new(2026, 6, 5) }
    status { "setup" }
  end
end
