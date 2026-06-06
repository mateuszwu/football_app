FactoryBot.define do
  factory :team_setup do
    association :match_day
    reroll_count { 0 }
  end
end
