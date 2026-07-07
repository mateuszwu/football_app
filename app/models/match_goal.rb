class MatchGoal < ApplicationRecord
  scope :active, -> { where(undone_at: nil) }

  belongs_to :match
  belongs_to :scoring_team, class_name: "Team"
  belongs_to :scorer_team_player, class_name: "TeamPlayer"
  belongs_to :assistant_team_player, class_name: "TeamPlayer", optional: true

  validates :scored_at, presence: true
  validate :scoring_team_belongs_to_match
  validate :scoring_team_is_playing
  validate :scorer_team_player_belongs_to_scoring_team
  validate :assistant_team_player_belongs_to_scoring_team
  validate :assistant_is_not_scorer
  validate :own_goal_scorer_belongs_to_opponent
  validate :own_goal_has_no_assistant

  def undone?
    undone_at.present?
  end

  def scorer
    scorer_team_player.player
  end

  def assistant
    assistant_team_player&.player
  end

  private

  def scoring_team_belongs_to_match
    return if match.blank? || scoring_team.blank?
    return if [ match.home_team_id, match.away_team_id ].include?(scoring_team_id)

    errors.add(:scoring_team, "must belong to the match")
  end

  def scoring_team_is_playing
    return if scoring_team.blank?
    return if scoring_team.playing?

    errors.add(:scoring_team, "must be a playing team")
  end

  def scorer_team_player_belongs_to_scoring_team
    return if scoring_team.blank? || scorer_team_player.blank?
    return if own_goal?
    return if scorer_team_player.team_id == scoring_team_id

    errors.add(:scorer_team_player, "must belong to the scoring team")
  end

  def assistant_team_player_belongs_to_scoring_team
    return if scoring_team.blank? || assistant_team_player.blank?
    return if assistant_team_player.team_id == scoring_team_id

    errors.add(:assistant_team_player, "must belong to the scoring team")
  end

  def assistant_is_not_scorer
    return if scorer_team_player_id.blank? || assistant_team_player_id.blank?
    return unless scorer_team_player_id == assistant_team_player_id

    errors.add(:assistant_team_player, "cannot be the scorer")
  end

  def own_goal_scorer_belongs_to_opponent
    return unless own_goal?
    return if match.blank? || scoring_team.blank? || scorer_team_player.blank?
    return if [ match.home_team_id, match.away_team_id ].include?(scorer_team_player.team_id) && scorer_team_player.team_id != scoring_team_id

    errors.add(:scorer_team_player, "must belong to the opponent for an own goal")
  end

  def own_goal_has_no_assistant
    return unless own_goal?
    return if assistant_team_player_id.blank?

    errors.add(:assistant_team_player, "cannot be present for an own goal")
  end
end
