class MatchDayVote < ApplicationRecord
  belongs_to :match_day_vote_token
  belongs_to :mvp_player, class_name: "Player"
  belongs_to :def_player, class_name: "Player"

  validates :match_day_vote_token_id, uniqueness: true
  validate :selected_players_are_not_the_voter

  private

  def selected_players_are_not_the_voter
    return if match_day_vote_token.blank? || match_day_vote_token.match_day_player.blank?

    voter_id = match_day_vote_token.match_day_player.player_id

    if mvp_player_id.present? && mvp_player_id == voter_id
      errors.add(:mvp_player_id, "cannot be the voter")
    end

    if def_player_id.present? && def_player_id == voter_id
      errors.add(:def_player_id, "cannot be the voter")
    end
  end
end
