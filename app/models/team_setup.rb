class TeamSetup < ApplicationRecord
  belongs_to :match_day
  has_many :teams, dependent: :destroy

  validates :reroll_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def fingerprint
    TeamSetups::GenerateFingerprint.call(team_setup: self)
  end
end
