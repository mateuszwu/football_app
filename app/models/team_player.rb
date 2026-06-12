class TeamPlayer < ApplicationRecord
  belongs_to :team
  belongs_to :player
  has_many :scored_match_goals, class_name: "MatchGoal", foreign_key: :scorer_team_player_id, dependent: :restrict_with_exception
  has_many :assisted_match_goals, class_name: "MatchGoal", foreign_key: :assistant_team_player_id, dependent: :restrict_with_exception

  before_validation :sync_player_snapshot, if: :player

  validates :player_name, presence: true
  validates :role_code, presence: true, inclusion: { in: Player::ROLE_CODES }

  private

  def sync_player_snapshot
    self.player_name ||= player.name
    default_role_code = self.class.column_defaults["role_code"]
    self.role_code = player.role_code if role_code.blank? || (new_record? && role_code == default_role_code)
  end
end
