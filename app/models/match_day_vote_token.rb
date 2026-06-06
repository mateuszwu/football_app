class MatchDayVoteToken < ApplicationRecord
  belongs_to :match_day_player
  has_one :match_day_vote, dependent: :destroy

  validates :token, presence: true, uniqueness: true
end
