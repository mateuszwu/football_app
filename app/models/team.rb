class Team < ApplicationRecord
  TEAM_TYPE_BASELINE = "baseline"
  TEAM_TYPE_MATCH = "match"
  TEAM_TYPES = [ TEAM_TYPE_BASELINE, TEAM_TYPE_MATCH ].freeze

  LINEUP_SOURCE_MANUAL = "manual"
  LINEUP_SOURCE_AUTO = "auto"
  LINEUP_SOURCE_COPIED = "copied"
  LINEUP_SOURCES = [
    LINEUP_SOURCE_MANUAL,
    LINEUP_SOURCE_AUTO,
    LINEUP_SOURCE_COPIED
  ].freeze

  RESULT_WIN = "win"
  RESULT_DRAW = "draw"
  RESULT_LOSS = "loss"
  RESULTS = [
    RESULT_WIN,
    RESULT_DRAW,
    RESULT_LOSS
  ].freeze

  belongs_to :match, optional: true
  belongs_to :team_setup
  belongs_to :source_team, class_name: "Team", optional: true
  belongs_to :captain, class_name: "Player", optional: true
  has_many :derived_teams, class_name: "Team", foreign_key: :source_team_id, dependent: :nullify
  has_many :match_goals, foreign_key: :scoring_team_id, dependent: :restrict_with_exception
  has_many :team_players, dependent: :destroy
  has_many :players, through: :team_players

  validates :name, presence: true
  validates :team_type, presence: true, inclusion: { in: TEAM_TYPES }
  validates :lineup_source, presence: true, inclusion: { in: LINEUP_SOURCES }
  validates :result, inclusion: { in: RESULTS }, allow_nil: true
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :captain_belongs_to_roster

  def fingerprint
    Teams::GenerateFingerprint.call(team: self)
  end

  def modified_from_source?
    return false unless source_team

    fingerprint != source_team.fingerprint
  end

  private

  def captain_belongs_to_roster
    return if captain_id.blank?
    return if team_players.any? { |team_player| team_player.player_id == captain_id }

    errors.add(:captain_id, "musi nalezec do tej druzyny")
  end
end
