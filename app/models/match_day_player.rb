class MatchDayPlayer < ApplicationRecord
  belongs_to :match_day
  belongs_to :player

  has_one :match_day_vote_token, dependent: :destroy
end
