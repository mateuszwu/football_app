class TeamPlayer < ApplicationRecord
  belongs_to :team
  belongs_to :player

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
