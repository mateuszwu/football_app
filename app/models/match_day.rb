class MatchDay < ApplicationRecord
  STATUSES = %w[setup ready in_progress finished].freeze

  belongs_to :season

  validates :played_on, presence: true
  validates :status, inclusion: { in: STATUSES }
end
