class TeamSetup < ApplicationRecord
  SETUP_METHOD_MANUAL = "manual"
  SETUP_METHOD_AUTO = "auto"
  SETUP_METHOD_COPIED = "copied"
  SETUP_METHODS = [
    SETUP_METHOD_MANUAL,
    SETUP_METHOD_AUTO,
    SETUP_METHOD_COPIED
  ].freeze

  belongs_to :match_day
  has_many :teams, dependent: :destroy

  validates :reroll_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :setup_method, inclusion: { in: SETUP_METHODS }, allow_nil: true

  def fingerprint
    TeamSetups::GenerateFingerprint.call(team_setup: self)
  end
end
