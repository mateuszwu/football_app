class MatchGoal < ApplicationRecord
  belongs_to :match
  belongs_to :scoring_team, class_name: "Team"
  belongs_to :scorer, class_name: "Player"
  belongs_to :assistant, class_name: "Player", optional: true

  validates :scored_at, presence: true
  validate :scoring_team_belongs_to_match
  validate :scorer_belongs_to_scoring_team
  validate :assistant_belongs_to_scoring_team
  validate :assistant_is_not_scorer

  private

  def scoring_team_belongs_to_match
    return if match.blank? || scoring_team.blank?
    return if [ match.home_team_id, match.away_team_id ].include?(scoring_team_id)

    errors.add(:scoring_team, "must belong to the match")
  end

  def scorer_belongs_to_scoring_team
    return if scoring_team.blank? || scorer.blank?
    return if scoring_team.players.exists?(scorer.id)

    errors.add(:scorer, "must belong to the scoring team")
  end

  def assistant_belongs_to_scoring_team
    return if scoring_team.blank? || assistant.blank?
    return if scoring_team.players.exists?(assistant.id)

    errors.add(:assistant, "must belong to the scoring team")
  end

  def assistant_is_not_scorer
    return if scorer_id.blank? || assistant_id.blank?
    return unless scorer_id == assistant_id

    errors.add(:assistant, "cannot be the scorer")
  end
end
