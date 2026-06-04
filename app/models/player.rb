class Player < ApplicationRecord
  APPROVAL_STATUSES = %w[pending approved rejected].freeze
  ROLE_CODES = %w[ANY GK DEF MID ATT].freeze

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
end
