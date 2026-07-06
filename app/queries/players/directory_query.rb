module Players
  class DirectoryQuery
    PlayerCard = Struct.new(
      :player,
      :season_stat,
      :matches_count,
      :wins,
      :draws,
      :losses,
      :win_rate,
      :goals,
      :assists,
      :last_played_on,
      keyword_init: true
    )
    Result = Struct.new(
      :players,
      :available_seasons,
      :selected_season,
      :query,
      :role,
      :total_players_count,
      :filtered_players_count,
      :active_roles_count,
      keyword_init: true
    )

    def self.call(params: {})
      new(params:).call
    end

    def initialize(params:)
      @params = params
    end

    def call
      players = filtered_players.to_a

      Result.new(
        players: player_cards(players),
        available_seasons: available_seasons,
        selected_season: selected_season,
        query: query,
        role: role,
        total_players_count: base_players.count,
        filtered_players_count: players.size,
        active_roles_count: base_players.distinct.count(:role_code)
      )
    end

    private

    attr_reader :params

    def base_players
      @base_players ||= Player.approved.active
    end

    def filtered_players
      scope = base_players.includes(:player_season_stats).order(:name)
      scope = scope.where(role_code: role) if role.present?
      scope = scope.where("LOWER(players.name) LIKE :query OR LOWER(players.nickname) LIKE :query", query: "%#{query.downcase}%") if query.present?
      scope
    end

    def player_cards(players)
      players.map do |player|
        entries = match_entries_by_player.fetch(player.id, [])
        season_stat = season_stats_by_player.fetch(player.id, nil)

        PlayerCard.new(
          player:,
          season_stat:,
          matches_count: entries.size,
          wins: entries.count { |entry| entry.fetch(:result) == Team::RESULT_WIN },
          draws: entries.count { |entry| entry.fetch(:result) == Team::RESULT_DRAW },
          losses: entries.count { |entry| entry.fetch(:result) == Team::RESULT_LOSS },
          win_rate: calculate_win_rate(entries),
          goals: goals_by_player.fetch(player.id, 0),
          assists: assists_by_player.fetch(player.id, 0),
          last_played_on: entries.map { |entry| entry.fetch(:played_on) }.compact.max
        )
      end
    end

    def match_entries_by_player
      @match_entries_by_player ||= begin
        entries = Hash.new { |hash, key| hash[key] = [] }

        finished_matches.each do |match|
          [ match.home_team, match.away_team ].compact.each do |team|
            team.team_players.each do |team_player|
              entries[team_player.player_id] << {
                match:,
                played_on: match.match_day.played_on,
                result: team_result(match, team)
              }
            end
          end
        end

        entries
      end
    end

    def finished_matches
      scope = Match
              .includes(:match_day, home_team: :team_players, away_team: :team_players)
              .where(status: Match::STATUS_FINISHED)
      scope = scope.joins(:match_day).where(match_days: { season_id: selected_season.id }) if selected_season.present?
      scope
    end

    def team_result(match, team)
      return team.result if Team::RESULTS.include?(team.result)
      return Team::RESULT_DRAW if match.home_score.to_i == match.away_score.to_i

      home_win = match.home_score.to_i > match.away_score.to_i
      team.id == match.home_team_id ? (home_win ? Team::RESULT_WIN : Team::RESULT_LOSS) : (home_win ? Team::RESULT_LOSS : Team::RESULT_WIN)
    end

    def calculate_win_rate(entries)
      return 0 if entries.empty?

      ((entries.count { |entry| entry.fetch(:result) == Team::RESULT_WIN }.to_f / entries.size) * 100).round
    end

    def season_stats_by_player
      @season_stats_by_player ||= begin
        return {} if selected_season.blank?

        PlayerSeasonStat.where(season: selected_season).index_by(&:player_id)
      end
    end

    def goals_by_player
      @goals_by_player ||= active_goal_scope
                         .joins(:scorer_team_player)
                         .group("team_players.player_id")
                         .count
    end

    def assists_by_player
      @assists_by_player ||= active_goal_scope
                           .joins(:assistant_team_player)
                           .where.not(assistant_team_player_id: nil)
                           .group("team_players.player_id")
                           .count
    end

    def active_goal_scope
      scope = MatchGoal.active.joins(match: :match_day)
      scope = scope.where(match_days: { season_id: selected_season.id }) if selected_season.present?
      scope
    end

    def available_seasons
      @available_seasons ||= Season.order(starts_on: :desc, created_at: :desc).to_a
    end

    def selected_season
      @selected_season ||= begin
        return if params[:season_id].blank?

        available_seasons.find { |season| season.id == params[:season_id].to_i }
      end
    end

    def query
      @query ||= params[:q].to_s.strip
    end

    def role
      @role ||= Player::ROLE_CODES.include?(params[:role].to_s) ? params[:role].to_s : nil
    end
  end
end
