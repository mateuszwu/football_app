module Players
  class OpponentRecordsQuery
    Record = Struct.new(
      :opponent,
      :matches_count,
      :wins,
      :draws,
      :losses,
      :player_goals,
      :player_assists,
      :opponent_goals,
      :opponent_assists,
      :team_goals_for,
      :team_goals_against,
      keyword_init: true
    ) do
      def win_rate
        return 0 if matches_count.to_i.zero?

        wins.to_f * 100 / matches_count
      end

      def loss_rate
        return 0 if matches_count.to_i.zero?

        losses.to_f * 100 / matches_count
      end
    end

    def self.call(player:, season: nil)
      new(player:, season:).call
    end

    def initialize(player:, season:)
      @player = player
      @season = season
    end

    def call
      records = Hash.new { |hash, opponent_id| hash[opponent_id] = blank_record_hash }

      scoped_matches.find_each do |match|
        player_team = team_for(match:, player:)
        opponent_team = opponent_team_for(match:, player_team:)
        next if player_team.blank? || opponent_team.blank?

        goal_contributions = goal_contributions_for(match)
        opponent_team.players.each do |opponent|
          update_record!(records[opponent.id], match:, player_team:, opponent:, goal_contributions:)
        end
      end

      players_by_id = Player.where(id: records.keys).index_by(&:id)

      records.map do |opponent_id, record|
        Record.new(opponent: players_by_id.fetch(opponent_id), **record)
      end.sort_by { |record| [ -record.losses, -record.loss_rate, -record.matches_count, record.opponent.name ] }
    end

    private

    attr_reader :player, :season

    def scoped_matches
      scope = Match.where(status: Match::STATUS_FINISHED)
                   .joins(:match_day)
                   .joins("LEFT JOIN team_players home_team_players ON home_team_players.team_id = matches.home_team_id")
                   .joins("LEFT JOIN team_players away_team_players ON away_team_players.team_id = matches.away_team_id")
                   .includes(home_team: :players, away_team: :players)
                   .includes(active_match_goals: [ { scorer_team_player: :player }, { assistant_team_player: :player } ])
                   .where("home_team_players.player_id = :player_id OR away_team_players.player_id = :player_id", player_id: player.id)
                   .distinct

      return scope unless season.present?

      scope.where(match_days: { season_id: season.id })
    end

    def team_for(match:, player:)
      return match.home_team if match.home_team.players.any? { |candidate| candidate.id == player.id }
      return match.away_team if match.away_team.players.any? { |candidate| candidate.id == player.id }

      nil
    end

    def opponent_team_for(match:, player_team:)
      return match.away_team if player_team == match.home_team
      return match.home_team if player_team == match.away_team

      nil
    end

    def update_record!(record, match:, player_team:, opponent:, goal_contributions:)
      record[:matches_count] += 1

      if match.draw?
        record[:draws] += 1
      elsif match.winner == player_team
        record[:wins] += 1
      else
        record[:losses] += 1
      end

      player_is_home = player_team.id == match.home_team_id
      record[:team_goals_for] += (player_is_home ? match.home_score : match.away_score).to_i
      record[:team_goals_against] += (player_is_home ? match.away_score : match.home_score).to_i
      record[:player_goals] += goal_contributions[player.id][:goals]
      record[:player_assists] += goal_contributions[player.id][:assists]
      record[:opponent_goals] += goal_contributions[opponent.id][:goals]
      record[:opponent_assists] += goal_contributions[opponent.id][:assists]
    end

    def goal_contributions_for(match)
      contributions_by_player = Hash.new do |hash, player_id|
        hash[player_id] = { goals: 0, assists: 0 }
      end

      match.active_match_goals.each_with_object(contributions_by_player) do |goal, contributions|
        next if goal.own_goal?

        contributions[goal.scorer_team_player.player_id][:goals] += 1
        next if goal.assistant_team_player.blank?

        contributions[goal.assistant_team_player.player_id][:assists] += 1
      end
    end

    def blank_record_hash
      {
        matches_count: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        player_goals: 0,
        player_assists: 0,
        opponent_goals: 0,
        opponent_assists: 0,
        team_goals_for: 0,
        team_goals_against: 0
      }
    end
  end
end
