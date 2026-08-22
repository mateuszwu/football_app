class Season < ApplicationRecord
  STATUS_ACTIVE = "active".freeze
  STATUS_CLOSED = "closed".freeze
  STATUS_ARCHIVED = "archived".freeze
  STATUSES = [ STATUS_ACTIVE, STATUS_CLOSED, STATUS_ARCHIVED ].freeze

  has_many :match_days, dependent: :destroy
  has_many :player_rating_changes, dependent: :destroy
  has_many :player_season_stats, dependent: :destroy
  has_many :season_pair_stats, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :starts_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :initial_elo, numericality: { only_integer: true, greater_than: 0 }
  validates :elo_k_factor, numericality: { only_integer: true, greater_than: 0 }
  validates :mvp_vote_bonus, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :def_vote_bonus, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :elo_k_value, numericality: { greater_than: 0 }
  validates :player_advantage_elo, numericality: { greater_than_or_equal_to: 0 }
  validates :season_elo_carryover_factor, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :goal_points, numericality: { greater_than_or_equal_to: 0 }
  validates :assist_points, numericality: { greater_than_or_equal_to: 0 }
  validates :mvp_max_points, numericality: { greater_than_or_equal_to: 0 }
  validates :def_max_points, numericality: { greater_than_or_equal_to: 0 }
  validates :voting_bonus_cap, numericality: { greater_than_or_equal_to: 0 }
  validates :expected_voters_count, numericality: { only_integer: true, greater_than: 0 }

  validate :ends_on_is_after_starts_on

  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :closed, -> { where(status: STATUS_CLOSED) }
  scope :archived, -> { where(status: STATUS_ARCHIVED) }

  def self.current_active
    active.order(starts_on: :desc, created_at: :desc).first
  end

  def match_days_count
    match_days.count
  end

  def player_appearances_count
    MatchDayPlayer.joins(:match_day).where(match_days: { season_id: id }).count
  end

  def unique_players_count
    MatchDayPlayer.joins(:match_day).where(match_days: { season_id: id }).distinct.count(:player_id)
  end

  def recent_match_days
    match_days.order(played_on: :desc, id: :desc)
  end

  def last_played_match_day_on
    match_days.finished.maximum(:played_on)
  end

  def appearances_leaderboard
    Player
      .joins(match_day_players: :match_day)
      .where(match_days: { season_id: id })
      .select("players.*, COUNT(match_day_players.id) AS appearances_count")
      .group("players.id")
      .order(Arel.sql("appearances_count DESC"), :name)
  end

  private

  def ends_on_is_after_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "must be on or after starts on")
  end
end
