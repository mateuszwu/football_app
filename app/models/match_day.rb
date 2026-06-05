class MatchDay < ApplicationRecord
  STATUSES = %w[setup ready in_progress finished].freeze

  belongs_to :season
  has_many :match_day_players, dependent: :destroy
  has_many :players, through: :match_day_players
  has_many :team_setups, dependent: :destroy

  validates :played_on, presence: true
  validates :status, inclusion: { in: STATUSES }
end
