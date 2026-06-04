class Player < ApplicationRecord
  validates :name, presence: true
  validates :nickname, presence: true, uniqueness: true
  validates :phone, presence: true, uniqueness: true
  validates :description, presence: true

  scope :active, -> { where(active: true) }
end
