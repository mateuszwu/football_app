class MatchDayVoteToken < ApplicationRecord
  belongs_to :match_day_player

  validates :token, presence: true, uniqueness: true
end
