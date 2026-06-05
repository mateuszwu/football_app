class MatchDayPlayer < ApplicationRecord
  belongs_to :match_day
  belongs_to :player
end
