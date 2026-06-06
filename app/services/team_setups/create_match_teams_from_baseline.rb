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
        team_setup.teams.where(team_type: "match").destroy_all

        baseline_teams.each do |baseline_team|
          match_team = team_setup.teams.create!(name: baseline_team.name, team_type: "match")

          baseline_team.team_players.order(:id).find_each do |team_player|
            match_team.team_players.create!(player: team_player.player)
          end
        end
      end

      true
    end

    private

    attr_reader :team_setup

    def baseline_teams
      @baseline_teams ||= team_setup.teams.where(team_type: "baseline").includes(:team_players)
    end
  end
end
