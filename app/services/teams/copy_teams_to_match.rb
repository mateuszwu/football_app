module Teams
  class CopyTeamsToMatch
    SOURCE_AUTO = :auto
    SOURCE_BASELINE = :baseline
    SOURCE_PREVIOUS = :previous

    def self.call(match:, source: SOURCE_AUTO)
      new(match:, source:).call
    end

    def initialize(match:, source:)
      @match = match
      @source = source
    end

    def call
      return false unless source_teams.size >= 2
      return false unless source_teams.count(&:playing?) >= 2

      Team.transaction do
        existing_match_teams = match.teams.order(:created_at, :id).to_a

        copied_teams = source_teams.map { |source_team| copy_team(source_team) }
        match.update!(home_team: copied_teams.first, away_team: copied_teams.second)
        Team.where(id: existing_match_teams.map(&:id)).destroy_all
      end

      true
    end

    private

    attr_reader :match, :source

    def source_teams
      @source_teams ||= case source
      when SOURCE_BASELINE
        baseline_teams
      when SOURCE_PREVIOUS
        previous_match_teams
      else
        previous_match_teams.presence || baseline_teams
      end
    end

    def previous_match_teams
      return [] unless previous_match

      previous_match.teams.order(:position, :created_at, :id)
    end

    def baseline_teams
      match.match_day
        .teams
        .where(team_type: Team::TEAM_TYPE_BASELINE)
        .order(:position, :created_at, :id)
    end

    def previous_match
      @previous_match ||= match.match_day.matches.where("id < ?", match.id).order(id: :desc).first
    end

    def copy_team(source_team)
      copied_team = source_team.team_setup.teams.create!(
        match: match,
        name: source_team.name,
        team_type: Team::TEAM_TYPE_MATCH,
        lineup_source: source_team.lineup_source,
        source_team: source_team,
        position: source_team.position,
        playing: source_team.playing
      )

      source_team.team_players.order(:id).find_each do |team_player|
        copied_team.team_players.create!(
          player: team_player.player,
          player_name: team_player.player_name,
          role_code: team_player.role_code,
          position: team_player.position,
          elo_before: team_player.elo_before,
          elo_after: team_player.elo_after,
          elo_delta: team_player.elo_delta
        )
      end

      copied_team
    end
  end
end
