class Match < ApplicationRecord
  belongs_to :match_day
  belongs_to :home_team, class_name: "Team"
  belongs_to :away_team, class_name: "Team"
  has_many :match_goals, dependent: :destroy
  has_many :player_rating_changes, dependent: :nullify

  validates :home_team_id, uniqueness: { scope: [ :match_day_id, :away_team_id ] }
  validates :home_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :away_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :teams_are_distinct

  def finished?
    !!finished_at
  end

  def in_progress?
    started_at.present? && !finished_at
  end

  def not_started?
    started_at.blank?
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
      home_score: match_goals.where(scoring_team_id: home_team_id).count,
      away_score: match_goals.where(scoring_team_id: away_team_id).count
    )
  end

  private

  def teams_are_distinct
    return if home_team_id.blank? || away_team_id.blank?
    return unless home_team_id == away_team_id

    errors.add(:away_team, "must be different from home team")
  end
end
