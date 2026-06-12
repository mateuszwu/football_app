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

  private

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
