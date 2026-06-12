module TeamSetups
  class MatchDayFormState
    DEFAULT_TEAM_COUNT = 2

    def initialize(match_day:, params:, players:)
      @match_day = match_day
      @params = params
      @players = players
    end

    def preview_auto_proposal_requested?
      params[:preview_auto_proposal].present? || params[:reroll_auto_proposal].present?
    end

    def form_params
      match_day_params.merge(
        player_ids: submitted_player_ids,
        teams_data: submitted_teams_data,
        setup_method: submitted_match_day_params[:setup_method],
        algorithm_version: submitted_match_day_params[:algorithm_version],
        reroll_count: submitted_match_day_params.fetch(:reroll_count, 0)
      )
    end

    def locals
      return preview_locals if preview_auto_proposal_requested?

      persisted_locals
    end

    private

    attr_reader :match_day, :params, :players

    def preview_locals
      {
        teams_data: generated_teams_data,
        selected_player_ids: current_selected_player_ids,
        setup_method: TeamSetup::SETUP_METHOD_AUTO,
        algorithm_version: Teams::GenerateProposal::ALGORITHM_VERSION,
        reroll_count: preview_reroll_count,
        team_count: current_team_count
      }
    end

    def persisted_locals
      {
        teams_data: current_teams_data,
        selected_player_ids: current_selected_player_ids,
        setup_method: current_setup_method,
        algorithm_version: current_algorithm_version,
        reroll_count: current_reroll_count,
        team_count: current_team_count
      }
    end

    def match_day_params
      submitted_match_day_params.slice(:season_id, :played_on).symbolize_keys
    end

    def submitted_match_day_params
      @submitted_match_day_params ||= begin
        raw_params = params.fetch(:match_day, {})
        raw_params = raw_params.to_unsafe_h if raw_params.respond_to?(:to_unsafe_h)
        raw_params.symbolize_keys
      end
    end

    def submitted_player_ids
      Array(submitted_match_day_params[:player_ids])
    end

    def submitted_teams_data
      teams_params = submitted_match_day_params[:teams_data]

      raw_teams = if teams_params.is_a?(Hash)
        teams_params.values
      else
        Array(teams_params)
      end

      raw_teams.map do |team|
        team = team.to_h.symbolize_keys
        { name: team[:name], player_ids: team[:player_ids] || [] }
      end
    end

    def current_teams_data
      return submitted_teams_data if submitted_match_day_params.key?(:teams_data)

      baseline_teams = match_day.teams.where(team_type: Team::TEAM_TYPE_BASELINE).order(:created_at)
      return baseline_teams.map { |team| { name: team.name, player_ids: team.player_ids.map(&:to_s) } } if baseline_teams.any?

      default_teams_data
    end

    def default_teams_data
      Array.new(current_team_count) do |index|
        { name: team_name(index), player_ids: [] }
      end
    end

    def current_selected_player_ids
      return submitted_player_ids.reject(&:blank?).map(&:to_i) if submitted_match_day_params.key?(:player_ids)

      match_day.player_ids
    end

    def current_setup_method
      submitted_match_day_params[:setup_method].presence || persisted_team_setup&.setup_method || TeamSetup::SETUP_METHOD_MANUAL
    end

    def current_algorithm_version
      submitted_match_day_params[:algorithm_version].presence || persisted_team_setup&.algorithm_version
    end

    def current_reroll_count
      submitted_match_day_params[:reroll_count].presence&.to_i || persisted_team_setup&.reroll_count || 0
    end

    def current_team_count
      requested_count = submitted_match_day_params[:team_count].presence&.to_i
      persisted_count = persisted_active_baseline_count
      count = requested_count || persisted_count || inferred_team_count_from_submission || DEFAULT_TEAM_COUNT

      clamp_team_count(count)
    end

    def inferred_team_count_from_submission
      return unless submitted_teams_data.any?

      submitted_teams_data.length
    end

    def persisted_active_baseline_count
      baseline_teams = match_day.teams.where(team_type: Team::TEAM_TYPE_BASELINE).order(:created_at)
      return if baseline_teams.empty?

      baseline_teams.count
    end

    def clamp_team_count(count)
      selected_count = current_selected_player_ids.size
      max_count = [ selected_count, DEFAULT_TEAM_COUNT ].max

      [ [ count.to_i, DEFAULT_TEAM_COUNT ].max, max_count ].min
    end

    def preview_reroll_count
      return current_reroll_count + 1 if params[:reroll_auto_proposal].present?

      current_reroll_count
    end

    def generated_teams_data
      Teams::GenerateProposal.call(
        players: selected_players_for_preview,
        options: {
          season: season_for_preview,
          team_count: current_team_count
        }
      ).map do |team|
        { name: team[:name], player_ids: team[:player_ids].map(&:to_s) }
      end
    end

    def selected_players_for_preview
      players.where(id: submitted_player_ids.reject(&:blank?)).includes(:player_season_stats)
    end

    def season_for_preview
      season_id = submitted_match_day_params[:season_id]
      return match_day.season if season_id.blank?

      Season.find_by(id: season_id)
    end

    def persisted_team_setup
      @persisted_team_setup ||= match_day.team_setups.order(:created_at).last
    end

    def team_name(index)
      suffix = ("A".ord + index).chr
      return "Team #{suffix}" if index < 26

      "Team #{index + 1}"
    end
  end
end
