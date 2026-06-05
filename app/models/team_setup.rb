class TeamSetup < ApplicationRecord
  belongs_to :match_day
  has_many :teams, dependent: :destroy

  def fingerprint
    TeamSetups::GenerateFingerprint.call(team_setup: self)
  end
end
