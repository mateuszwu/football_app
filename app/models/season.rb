class Season < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :starts_on, presence: true
  validates :initial_elo, numericality: { only_integer: true, greater_than: 0 }
  validates :elo_k_factor, numericality: { only_integer: true, greater_than: 0 }
  validates :mvp_vote_bonus, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :def_vote_bonus, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :ends_on_is_after_starts_on

  scope :active, -> { where(active: true) }

  private

  def ends_on_is_after_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "must be on or after starts on")
  end
end
