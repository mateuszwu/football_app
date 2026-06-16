module Players
  class PublicProfileQuery
    MatchEntry = Struct.new(:match, :team, keyword_init: true)
    Profile = Struct.new(
      :available_seasons,
      :selected_season,
      :season_stat,
      :match_entries,
      :matches_count,
      :wins,
      :draws,
      :losses,
      :win_rate,
      keyword_init: true
    )

    def self.call(player:, season_id: nil)
      new(player:, season_id:).call
    end

    def initialize(player:, season_id:)
      @player = player
      @season_id = season_id
    end

    def call
      seasons = available_seasons.to_a
      selected_season = select_season(seasons)
      season_stat = player.player_season_stats.find_by(season: selected_season) if selected_season
      match_entries = filtered_match_entries(selected_season)

      Profile.new(
        available_seasons: seasons,
        selected_season:,
        season_stat:,
        match_entries:,
        matches_count: match_entries.size,
        wins: match_entries.count { |entry| entry.team.result == Team::RESULT_WIN },
        draws: match_entries.count { |entry| entry.team.result == Team::RESULT_DRAW },
        losses: match_entries.count { |entry| entry.team.result == Team::RESULT_LOSS },
        win_rate: calculate_win_rate(match_entries)
      )
    end

    private

    attr_reader :player, :season_id

    def available_seasons
      Season.where(id: season_ids).order(starts_on: :desc, created_at: :desc)
    end

    def season_ids
      @season_ids ||= (
        player.match_days.distinct.pluck(:season_id) +
        player_matches.map { |match| match.match_day.season_id } +
        player.player_season_stats.distinct.pluck(:season_id)
      ).uniq
    end

    def select_season(seasons)
      return if seasons.empty?

      seasons.find { |season| season.id == season_id.to_i } || seasons.first
    end

    def filtered_match_entries(selected_season)
      entries = match_entries
      entries = entries.select { |entry| entry.match.match_day.season_id == selected_season.id } if selected_season
      entries.sort_by { |entry| [ entry.match.match_day.played_on, entry.match.id ] }.reverse
    end

    def match_entries
      @match_entries ||= player_matches.filter_map do |match|
        team = match.home_team if match.home_team.team_players.any? { |team_player| team_player.player_id == player.id }
        team ||= match.away_team if match.away_team.team_players.any? { |team_player| team_player.player_id == player.id }
        next if team.blank?

        MatchEntry.new(match:, team:)
      end
    end

    def calculate_win_rate(match_entries)
      return 0 if match_entries.empty?

      ((match_entries.count { |entry| entry.team.result == Team::RESULT_WIN }.to_f / match_entries.size) * 100).round
    end

    def player_matches
      @player_matches ||= Match
                            .joins("LEFT JOIN team_players home_team_players ON home_team_players.team_id = matches.home_team_id")
                            .joins("LEFT JOIN team_players away_team_players ON away_team_players.team_id = matches.away_team_id")
                            .joins(:match_day)
                            .includes(:match_day, home_team: :team_players, away_team: :team_players)
                            .where(status: Match::STATUS_FINISHED)
                            .where("home_team_players.player_id = :player_id OR away_team_players.player_id = :player_id", player_id: player.id)
                            .distinct
    end
  end
end
