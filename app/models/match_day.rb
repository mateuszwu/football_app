class MatchDay < ApplicationRecord
  STATUSES = %w[setup ready in_progress finished].freeze
  ALLOWED_STATUS_TRANSITIONS = {
    "setup" => %w[ready],
    "ready" => %w[setup in_progress],
    "in_progress" => %w[finished],
    "finished" => []
  }.freeze

  belongs_to :season
  has_many :match_day_players, dependent: :destroy
  has_many :players, through: :match_day_players
  has_many :team_setups, dependent: :destroy
  has_many :teams, through: :team_setups

  validates :played_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :status_transition_is_allowed

  def ready_for_match?
    selected_player_ids = match_day_players.order(:player_id).pluck(:player_id)
    return false if selected_player_ids.empty?

    baseline_teams = teams.where(team_type: "baseline")
    return false unless baseline_teams.where(name: "Team A").exists?
    return false unless baseline_teams.where(name: "Team B").exists?

    assigned_player_ids = baseline_teams.joins(:team_players).distinct.order("team_players.player_id").pluck("team_players.player_id")

    assigned_player_ids == selected_player_ids
  end

  def sync_setup_status!
    update!(status: ready_for_match? ? "ready" : "setup")
  end

  def can_transition_to?(new_status)
    return true if new_status == status

    ALLOWED_STATUS_TRANSITIONS.fetch(status, []).include?(new_status)
  end

  private

  def status_transition_is_allowed
    return unless persisted?
    return unless will_save_change_to_status?

    previous_status, next_status = status_change_to_be_saved
    return if ALLOWED_STATUS_TRANSITIONS.fetch(previous_status, []).include?(next_status)

    errors.add(:status, "cannot transition from #{previous_status} to #{next_status}")
  end
end
