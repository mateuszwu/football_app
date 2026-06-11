FactoryBot.define do
  factory :player_season_stat do
    player
    season
    elo { 1000 }
  end
end
