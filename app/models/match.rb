class Match < ApplicationRecord
  STATUS_PENDING = "pending"
  STATUS_IN_PROGRESS = "in_progress"
  STATUS_FINISHED = "finished"
  STATUSES = [
    STATUS_PENDING,
    STATUS_IN_PROGRESS,
    STATUS_FINISHED
  ].freeze

  belongs_to :match_day
  belongs_to :team_setup, optional: true
  belongs_to :home_team, class_name: "Team"
  belongs_to :away_team, class_name: "Team"
  has_many :match_goals, dependent: :destroy
  has_many :active_match_goals, -> { active }, class_name: "MatchGoal", dependent: :destroy, inverse_of: :match
  has_many :match_player_changes, dependent: :destroy
  has_many :player_rating_changes, dependent: :nullify
  has_many :teams, dependent: :nullify

  validates :home_team_id, uniqueness: { scope: [ :match_day_id, :away_team_id ] }
  validates :status, inclusion: { in: STATUSES }
  validates :home_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :away_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :teams_are_distinct

  before_validation :sync_status_from_timing

  def finished?
    status == STATUS_FINISHED
  end

  def in_progress?
    status == STATUS_IN_PROGRESS
  end

  def not_started?
    status == STATUS_PENDING
  end

  def home_win?
    home_score > away_score
  end

  def away_win?
    away_score > home_score
  end

  def draw?
    home_score == away_score
  end

  def winner
    return nil if not_started?

    home_win? ? home_team : (away_win? ? away_team : nil)
  end

  def loser
    return nil if not_started?

    home_win? ? away_team : (away_win? ? home_team : nil)
  end

  def timer_reference_time
    finished_at || Time.current
  end

  def elapsed_seconds(reference_time = timer_reference_time)
    return 0 if started_at.blank?

    [ (reference_time.to_i - started_at.to_i), 0 ].max
  end

  def recalculate_score!
    update!(
      home_score: active_match_goals.where(scoring_team_id: home_team_id).count,
      away_score: active_match_goals.where(scoring_team_id: away_team_id).count
    )
  end

  def match_teams
    [ home_team, away_team ].compact
  end

  def player_team_at(player_or_id, occurred_at: timer_reference_time)
    player_id = player_or_id.respond_to?(:id) ? player_or_id.id : player_or_id.to_i
    team_id = initial_team_id_for(player_id)

    match_player_changes
      .where(player_id:)
      .where("occurred_at <= ?", occurred_at)
      .order(:occurred_at, :id)
      .each { |change| team_id = change.to_team_id }

    match_teams.find { |team| team.id == team_id }
  end

  def players_for_team_at(team, occurred_at: timer_reference_time)
    player_ids = match_player_ids.select do |player_id|
      player_team_at(player_id, occurred_at:) == team
    end

    Player.where(id: player_ids).to_a.sort_by { |player| player_ids.index(player.id) }
  end

  def final_players_for(team)
    players_for_team_at(team, occurred_at: timer_reference_time)
  end

  private

  def match_player_ids
    team_player_ids = match_teams.flat_map { |team| team.team_players.pluck(:player_id) }
    change_player_ids = match_player_changes.distinct.pluck(:player_id)
    (team_player_ids + change_player_ids).uniq
  end

  def initial_team_id_for(player_id)
    first_change = match_player_changes.where(player_id:).order(:occurred_at, :id).first
    return first_change.from_team_id if first_change

    match_teams.find do |team|
      team.team_players.any? { |team_player| team_player.player_id == player_id }
    end&.id
  end

  def sync_status_from_timing
    self.status = if finished_at.present?
      STATUS_FINISHED
    elsif started_at.present?
      STATUS_IN_PROGRESS
    else
      STATUS_PENDING
    end
  end

  def teams_are_distinct
    return if home_team_id.blank? || away_team_id.blank?
    return unless home_team_id == away_team_id

    errors.add(:away_team, "must be different from home team")
  end
end
