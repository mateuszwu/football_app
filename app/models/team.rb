class Team < ApplicationRecord
  TEAM_TYPES = %w[baseline match].freeze

  belongs_to :team_setup

  validates :name, presence: true
  validates :team_type, presence: true, inclusion: { in: TEAM_TYPES }
end
