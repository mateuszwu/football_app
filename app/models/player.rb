class Player < ApplicationRecord
  ROLE_CODES = %w[ANY GK DEF MID ATT].freeze

  validates :name, presence: true
  validates :nickname, presence: true, uniqueness: true
  validates :phone, presence: true, uniqueness: true
  validates :description, presence: true
  validates :role_code, inclusion: { in: ROLE_CODES }

  scope :active, -> { where(active: true) }
end
