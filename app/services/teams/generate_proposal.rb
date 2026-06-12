module Teams
  class GenerateProposal
    ALGORITHM_VERSION = "v1"
    DEFAULT_ELO = 1000

    def self.call(players:, options: {})
      new(players:, options:).call
    end

    def initialize(players:, options: {})
      @players = Array(players)
      @season = options[:season]
    end

    def call
      return [] if players.empty?

      assigned_teams = [
        build_team("Team A"),
        build_team("Team B")
      ]

      sorted_players.each_with_index do |player, index|
        if index < 2
          assign_player(assigned_teams[index], player)
        elsif waiting_team_required?(index)
          waiting_team[:player_ids] << player.id
        else
          assign_player(lower_elo_team(assigned_teams), player)
        end
      end

      teams = assigned_teams
      teams << waiting_team if waiting_team[:player_ids].any?
      teams
    end

    private

    attr_reader :players, :season

    def sorted_players
      @sorted_players ||= players.sort_by do |player|
        [ -player_elo(player), player.name, player.id ]
      end
    end

    def player_elo(player)
      if season
        player.player_season_stats.find { |stat| stat.season_id == season.id }&.elo || DEFAULT_ELO
      else
        DEFAULT_ELO
      end
    end

    def lower_elo_team(teams)
      teams.min_by { |team| [ team[:elo_total], team[:player_ids].length, team[:name] ] }
    end

    def assign_player(team, player)
      team[:player_ids] << player.id
      team[:elo_total] += player_elo(player)
    end

    def build_team(name)
      {
        name:,
        team_type: Team::TEAM_TYPE_BASELINE,
        player_ids: [],
        elo_total: 0
      }
    end

    def waiting_team
      @waiting_team ||= build_team("Waiting")
    end

    def waiting_team_required?(index)
      players.count.odd? && index == players.count - 1
    end
  end
end
