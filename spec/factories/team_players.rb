FactoryBot.define do
  factory :team_player do
    association :team
    association :player
    player_name { player&.name || "Player Snapshot" }
    role_code { player&.role_code || Player::ROLE_CODES.first }
  end
end
