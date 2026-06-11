class PlayerRatingChange < ApplicationRecord
  belongs_to :player
  belongs_to :season
  belongs_to :match, optional: true

  validates :elo_before, presence: true
  validates :elo_after, presence: true
  validates :delta, presence: true
end
