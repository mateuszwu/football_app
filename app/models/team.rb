class Team < ApplicationRecord
  TEAM_TYPES = %w[baseline match].freeze

  belongs_to :team_setup
  has_many :team_players, dependent: :destroy
  has_many :players, through: :team_players

  validates :name, presence: true
  validates :team_type, presence: true, inclusion: { in: TEAM_TYPES }
end
