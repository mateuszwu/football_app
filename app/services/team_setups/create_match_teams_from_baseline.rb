module TeamSetups
  class CreateMatchTeamsFromBaseline
    def self.call(team_setup:)
      new(team_setup:).call
    end

    def initialize(team_setup:)
      @team_setup = team_setup
    end

    def call
      return false unless baseline_teams.any?

      Team.transaction do
        team_setup.teams.where(team_type: Team::TEAM_TYPE_MATCH).destroy_all

        baseline_teams.each do |baseline_team|
          match_team = team_setup.teams.create!(
            name: baseline_team.name,
            team_type: Team::TEAM_TYPE_MATCH,
            lineup_source: Team::LINEUP_SOURCE_AUTO,
            source_team: baseline_team
          )

          baseline_team.team_players.order(:id).find_each do |team_player|
            match_team.team_players.create!(
              player: team_player.player,
              player_name: team_player.player_name,
              role_code: team_player.role_code,
              position: team_player.position,
              elo_before: team_player.elo_before,
              elo_after: team_player.elo_after,
              elo_delta: team_player.elo_delta
            )
          end
          match_team.update!(captain_id: baseline_team.captain_id) if baseline_team.captain_id.present?
        end
      end

      true
    end

    private

    attr_reader :team_setup

    def baseline_teams
      @baseline_teams ||= team_setup.teams.where(team_type: Team::TEAM_TYPE_BASELINE).includes(:team_players)
    end
  end
end
