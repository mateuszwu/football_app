FactoryBot.define do
  factory :match_day_vote_token do
    association :match_day_player
    sequence(:token) { |n| "vote-token-#{n}" }
    expires_at { 48.hours.from_now }
    used_at { nil }
  end
end
