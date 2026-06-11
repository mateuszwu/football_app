FactoryBot.define do
  factory :player_rating_change do
    player
    season
    match { nil }
    elo_before { 1000 }
    elo_after { 1016 }
    delta { 16 }
  end
end
