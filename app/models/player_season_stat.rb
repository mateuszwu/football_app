class PlayerSeasonStat < ApplicationRecord
  belongs_to :player
  belongs_to :season

  validates :player_id, uniqueness: { scope: :season_id }
end
