class UpdateMatchDay
  def self.call(match_day:, params:, available_players:)
    new(match_day:, params:, available_players:).call
  end

  def initialize(match_day:, params:, available_players:)
    @match_day = match_day
    @params = params
    @available_players = available_players
  end

  def call
    MatchDay.transaction do
      match_day.update!(match_day_attributes)
      sync_match_day_players!
      save_manual_teams!
      match_day.sync_setup_status!
      GenerateMatchDayVoteTokens.call(match_day:)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  attr_reader :available_players, :match_day, :params

  def selected_player_ids
    available_players.where(id: params.fetch(:player_ids, []).reject(&:blank?)).pluck(:id)
  end

  def match_day_attributes
    params.slice(:season_id, :played_on)
  end

  def sync_match_day_players!
    match_day.match_day_players.where.not(player_id: selected_player_ids).find_each(&:destroy!)

    missing_player_ids = selected_player_ids - match_day.match_day_players.pluck(:player_id)
    missing_player_ids.each do |player_id|
      match_day.match_day_players.create!(player_id: player_id)
    end
  end

  def save_manual_teams!
    result = TeamSetups::SaveManualTeams.call(
      match_day:,
      selected_player_ids:,
      teams_data: params.fetch(:teams_data, []),
      setup_method: team_setup_method,
      lineup_source: team_lineup_source,
      algorithm_version: team_algorithm_version,
      reroll_count: team_reroll_count
    )

    raise ActiveRecord::RecordInvalid.new(match_day) unless result
  end

  def team_setup_method
    return TeamSetup::SETUP_METHOD_AUTO if params[:setup_method] == TeamSetup::SETUP_METHOD_AUTO

    TeamSetup::SETUP_METHOD_MANUAL
  end

  def team_lineup_source
    return Team::LINEUP_SOURCE_AUTO if team_setup_method == TeamSetup::SETUP_METHOD_AUTO

    Team::LINEUP_SOURCE_MANUAL
  end

  def team_algorithm_version
    return nil unless team_setup_method == TeamSetup::SETUP_METHOD_AUTO

    params[:algorithm_version].presence || Teams::GenerateProposal::ALGORITHM_VERSION
  end

  def team_reroll_count
    params[:reroll_count].to_i
  end
end
