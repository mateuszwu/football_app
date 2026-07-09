class Player < ApplicationRecord
  APPROVAL_STATUSES = %w[pending approved rejected].freeze
  ROLE_CODES = %w[ANY GK DEF MID ATT].freeze

  has_many :match_day_players, dependent: :destroy
  has_many :match_days, through: :match_day_players
  has_many :player_rating_changes, dependent: :destroy
  has_many :player_season_stats, dependent: :destroy
  has_many :team_players, dependent: :destroy
  has_many :teams, through: :team_players

  before_validation :normalize_phone
  after_create :assign_missing_identity
  after_update :assign_missing_identity_after_public_activation, if: :saved_change_to_public_visibility?

  validates :name, presence: true
  validates :nickname, presence: true, uniqueness: true
  validates :phone, uniqueness: true, allow_nil: true
  validates :description, presence: true
  validates :approval_status, inclusion: { in: APPROVAL_STATUSES }
  validates :role_code, inclusion: { in: ROLE_CODES }
  validates :profile_color_key, inclusion: { in: PlayerIdentity.color_keys }, allow_blank: true
  validates :profile_icon, inclusion: { in: ->(_) { PlayerIdentity.icons + PlayerIdentity::FALLBACK_ICONS } }, allow_blank: true
  validates :profile_color_hex, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :approved, -> { where(approval_status: "approved") }
  scope :active_public, -> { approved.active }
  scope :pending, -> { where(approval_status: "pending") }
  scope :rejected, -> { where(approval_status: "rejected") }

  def match_history
    match_days.includes(:season).order(played_on: :desc, id: :desc)
  end

  def played_with
    Players::SharedMatchDaysQuery.call(player: self)
  end

  def profile_color
    profile_color_hex.presence || PlayerIdentity.hex_for(profile_color_key)
  end

  def profile_icon_name
    PlayerIdentity.safe_icon(profile_icon)
  end

  def profile_color_name
    PlayerIdentity.name_for(profile_color_key)
  end

  private

  def normalize_phone
    self.phone = phone.to_s.strip.presence
  end

  def assign_missing_identity
    Players::AssignIdentity.call(player: self) if identity_missing?
  end

  def assign_missing_identity_after_public_activation
    assign_missing_identity if approval_status == "approved" && active?
  end

  def saved_change_to_public_visibility?
    saved_change_to_approval_status? || saved_change_to_active?
  end

  def identity_missing?
    profile_icon.blank? || profile_color_key.blank? || profile_color_hex.blank?
  end
end
