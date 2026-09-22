class MatchPlayerChange < ApplicationRecord
  EVENT_TEAM_CHANGE = "team_change"
  EVENT_SUBSTITUTION_IN = "substitution_in"
  EVENT_SUBSTITUTION_OUT = "substitution_out"
  EVENT_TYPES = [ EVENT_TEAM_CHANGE, EVENT_SUBSTITUTION_IN, EVENT_SUBSTITUTION_OUT ].freeze

  belongs_to :match
  belongs_to :player
  belongs_to :from_team, class_name: "Team", optional: true
  belongs_to :to_team, class_name: "Team", optional: true

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  validate :one_side_of_transition_is_present
  validate :teams_are_different
  validate :teams_belong_to_match

  def team_change?
    event_type == EVENT_TEAM_CHANGE
  end

  def substitution_in?
    event_type == EVENT_SUBSTITUTION_IN
  end

  def substitution_out?
    event_type == EVENT_SUBSTITUTION_OUT
  end

  private

  def one_side_of_transition_is_present
    return if from_team_id.present? || to_team_id.present?

    errors.add(:base, "from_team or to_team must be present")
  end

  def teams_are_different
    return if from_team_id.blank? || to_team_id.blank?
    return unless from_team_id == to_team_id

    errors.add(:to_team, "must be different from from team")
  end

  def teams_belong_to_match
    return if match.blank?

    match_team_ids = [ match.home_team_id, match.away_team_id ].compact
    [ [ :from_team, from_team_id ], [ :to_team, to_team_id ] ].each do |attribute, team_id|
      next if team_id.blank? || match_team_ids.include?(team_id)

      errors.add(attribute, "must belong to the match")
    end
  end
end
