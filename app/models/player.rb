class Player < ApplicationRecord
  APPROVAL_STATUSES = %w[pending approved rejected].freeze
  ROLE_CODES = %w[ANY GK DEF MID ATT].freeze

  has_many :match_day_players, dependent: :destroy
  has_many :match_days, through: :match_day_players

  validates :name, presence: true
  validates :nickname, presence: true, uniqueness: true
  validates :phone, presence: true, uniqueness: true
  validates :description, presence: true
  validates :approval_status, inclusion: { in: APPROVAL_STATUSES }
  validates :role_code, inclusion: { in: ROLE_CODES }

  scope :active, -> { where(active: true) }
  scope :approved, -> { where(approval_status: "approved") }
  scope :pending, -> { where(approval_status: "pending") }
  scope :rejected, -> { where(approval_status: "rejected") }

  def match_history
    match_days.includes(:season).order(played_on: :desc, id: :desc)
  end

  def played_with
    Players::SharedMatchDaysQuery.call(player: self)
  end
end
