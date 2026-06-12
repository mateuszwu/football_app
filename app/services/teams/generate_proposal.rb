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
      @requested_team_count = options[:team_count]
    end

    def call
      return [] if players.empty?

      assigned_teams = build_active_teams

      sorted_players.each_with_index do |player, index|
        if index < assigned_teams.size
          assign_player(assigned_teams[index], player)
        else
          assign_player(lower_elo_team(assigned_teams), player)
        end
      end

      assigned_teams
    end

    private

    attr_reader :players, :requested_team_count, :season

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

    def build_active_teams
      Array.new(team_count) do |index|
        build_team(team_name(index))
      end
    end

    def team_count
      @team_count ||= begin
        normalized_count = requested_team_count.to_i
        normalized_count = 2 if normalized_count < 2
        [ normalized_count, players.count ].min
      end
    end

    def team_name(index)
      suffix = ("A".ord + index).chr
      return "Team #{suffix}" if index < 26

      "Team #{index + 1}"
    end
  end
end
