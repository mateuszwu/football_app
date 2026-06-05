class Season < ApplicationRecord
  has_many :match_days, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :starts_on, presence: true
  validates :initial_elo, numericality: { only_integer: true, greater_than: 0 }
  validates :elo_k_factor, numericality: { only_integer: true, greater_than: 0 }
  validates :mvp_vote_bonus, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :def_vote_bonus, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :ends_on_is_after_starts_on

  scope :active, -> { where(active: true) }

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

  private

  def ends_on_is_after_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "must be on or after starts on")
  end
end
