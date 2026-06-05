class MatchDay < ApplicationRecord
  STATUSES = %w[setup ready in_progress finished].freeze

  belongs_to :season
  has_many :match_day_players, dependent: :destroy

  validates :played_on, presence: true
  validates :status, inclusion: { in: STATUSES }
end
