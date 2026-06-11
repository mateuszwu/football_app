module Ratings
  class RecalculateSeasonElo
    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      elo_map = Hash.new(season.initial_elo)

      finished_match_days.each do |match_day|
        finished_matches(match_day).each do |match|
          process_match(match, elo_map)
        end

        apply_vote_bonuses(match_day, elo_map)
      end

      persist(elo_map)
    end

    private

    attr_reader :season

    def finished_match_days
      season.match_days
            .finished
            .order(:played_on, :id)
    end

    def finished_matches(match_day)
      match_day.matches
               .includes(home_team: :players, away_team: :players)
               .where.not(finished_at: nil)
               .order(:started_at, :id)
    end

    def process_match(match, elo_map)
      home_players = match.home_team.players.to_a
      away_players = match.away_team.players.to_a

      return if home_players.empty? || away_players.empty?

      home_avg = average_elo(home_players, elo_map)
      away_avg = average_elo(away_players, elo_map)

      home_score, away_score = match_scores(match)

      home_players.each do |player|
        elo_map[player.id] += elo_delta(elo_map[player.id], away_avg, home_score, season.elo_k_factor)
      end

      away_players.each do |player|
        elo_map[player.id] += elo_delta(elo_map[player.id], home_avg, away_score, season.elo_k_factor)
      end
    end

    def apply_vote_bonuses(match_day, elo_map)
      match_day_votes(match_day).each do |vote|
        elo_map[vote.mvp_player_id] += vote.mvp_bonus
        elo_map[vote.def_player_id] += vote.def_bonus
      end
    end

    def average_elo(players, elo_map)
      players.sum { |p| elo_map[p.id] }.to_f / players.size
    end

    def match_day_votes(match_day)
      MatchDayVote
        .joins(match_day_vote_token: { match_day_player: :match_day })
        .where(match_days: { id: match_day.id })
        .includes(:mvp_player, :def_player, match_day_vote_token: { match_day_player: :match_day })
    end

    def match_scores(match)
      if match.home_win?
        [ 1.0, 0.0 ]
      elsif match.away_win?
        [ 0.0, 1.0 ]
      else
        [ 0.5, 0.5 ]
      end
    end

    def elo_delta(player_elo, opponent_avg_elo, actual_score, k_factor)
      expected = 1.0 / (1.0 + 10.0**((opponent_avg_elo - player_elo) / 400.0))
      (k_factor * (actual_score - expected)).round
    end

    def persist(elo_map)
      Player.transaction do
        elo_map.each do |player_id, elo|
          Player.where(id: player_id).update_all(elo: elo)
        end
      end
    end
  end
end
