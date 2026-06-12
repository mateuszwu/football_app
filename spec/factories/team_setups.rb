FactoryBot.define do
  factory :team_setup do
    association :match_day
    setup_method { TeamSetup::SETUP_METHOD_MANUAL }
    reroll_count { 0 }
  end
end
