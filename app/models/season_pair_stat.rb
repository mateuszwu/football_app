class SeasonPairStat < ApplicationRecord
  COUNT_COLUMNS = %i[
    shared_match_days_count
    shared_matches_count
    wins
    draws
    losses
    goals
    assists
    mutual_assists
  ].freeze

  belongs_to :season
  belongs_to :player_one, class_name: "Player"
  belongs_to :player_two, class_name: "Player"

  validates :player_one_id, uniqueness: { scope: [ :season_id, :player_two_id ] }
  validates(*COUNT_COLUMNS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })
  validate :players_are_ordered

  private

  def players_are_ordered
    return if player_one_id.blank? || player_two_id.blank?
    return if player_one_id < player_two_id

    errors.add(:player_two_id, "must be greater than player_one_id")
  end
end
