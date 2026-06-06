class MatchDayVote < ApplicationRecord
  belongs_to :match_day_vote_token
  belongs_to :mvp_player, class_name: "Player"
  belongs_to :def_player, class_name: "Player"

  validates :match_day_vote_token_id, uniqueness: true
end
