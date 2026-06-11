class MatchDayVoteToken < ApplicationRecord
  belongs_to :match_day_player
  has_one :match_day_vote, dependent: :destroy

  validates :token, presence: true, uniqueness: true

  def used?
    used_at.present?
  end

  def mark_used!
    return if used_at.present?

    update!(used_at: Time.current)
  end
end
