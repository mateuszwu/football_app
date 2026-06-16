module Players
  class OpponentRecordsQuery
    Record = Struct.new(:opponent, :matches_count, :wins, :draws, :losses, keyword_init: true)

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

        opponent_team.players.each do |opponent|
          update_record!(records[opponent.id], match:, player_team:)
        end
      end

      players_by_id = Player.where(id: records.keys).index_by(&:id)

      records.map do |opponent_id, record|
        Record.new(opponent: players_by_id.fetch(opponent_id), **record)
      end.sort_by { |record| [ -record.matches_count, record.opponent.name ] }
    end

    private

    attr_reader :player, :season

    def scoped_matches
      scope = Match.where(status: Match::STATUS_FINISHED)
                   .joins(:match_day)
                   .joins("LEFT JOIN team_players home_team_players ON home_team_players.team_id = matches.home_team_id")
                   .joins("LEFT JOIN team_players away_team_players ON away_team_players.team_id = matches.away_team_id")
                   .includes(home_team: :players, away_team: :players)
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

    def update_record!(record, match:, player_team:)
      record[:matches_count] += 1

      case player_team.result
      when Team::RESULT_WIN
        record[:wins] += 1
      when Team::RESULT_DRAW
        record[:draws] += 1
      when Team::RESULT_LOSS
        record[:losses] += 1
      end
    end

    def blank_record_hash
      { matches_count: 0, wins: 0, draws: 0, losses: 0 }
    end
  end
end
