class CreateMatchDay
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
      team_a_player_ids: params.fetch(:team_a_player_ids, []),
      team_b_player_ids: params.fetch(:team_b_player_ids, [])
    )

    raise ActiveRecord::RecordInvalid.new(match_day) unless result
  end
end
