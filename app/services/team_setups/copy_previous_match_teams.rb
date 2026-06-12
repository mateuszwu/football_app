module TeamSetups
  class CopyPreviousMatchTeams
    def self.call(match_day:)
      new(match_day:).call
    end

    def initialize(match_day:)
      @match_day = match_day
    end

    def call
      return false unless previous_match_day

      previous_match_teams = previous_match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH).includes(:team_players)
      return false if previous_match_teams.empty?

      Team.transaction do
        team_setup = match_day.team_setups.first_or_create!
        team_setup.update!(setup_method: TeamSetup::SETUP_METHOD_COPIED)
        team_setup.teams.where(team_type: Team::TEAM_TYPE_MATCH).destroy_all

        previous_match_teams.each do |previous_team|
          match_team = team_setup.teams.create!(
            name: previous_team.name,
            team_type: Team::TEAM_TYPE_MATCH,
            lineup_source: Team::LINEUP_SOURCE_COPIED,
            source_team: previous_team
          )

          previous_team.team_players.order(:id).find_each do |team_player|
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
        end
      end

      true
    end

    private

    attr_reader :match_day

    def previous_match_day
      @previous_match_day ||= MatchDay
        .where(season_id: match_day.season_id)
        .where("played_on < ?", match_day.played_on)
        .order(played_on: :desc, id: :desc)
        .first
    end
  end
end
