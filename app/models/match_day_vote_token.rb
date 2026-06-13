class MatchDayVoteToken < ApplicationRecord
  belongs_to :match_day_player
  has_one :match_day_vote, dependent: :destroy

  validates :match_day_player_id, uniqueness: true
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def used?
    used_at.present?
  end

  def expired?(reference_time = Time.current)
    expires_at <= reference_time
  end

  def mark_used!
    return if used_at.present?

    update!(used_at: Time.current)
  end
end
