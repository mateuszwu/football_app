module Votes
  class SelectablePlayersQuery
    def self.call(match_day_vote_token:)
      new(match_day_vote_token:).call
    end

    def initialize(match_day_vote_token:)
      @match_day_vote_token = match_day_vote_token
    end

    def call
      match_day_vote_token.match_day_player.match_day.players
        .where.not(id: voter_id)
        .order(:name)
    end

    private

    attr_reader :match_day_vote_token

    def voter_id
      match_day_vote_token.match_day_player.player_id
    end
  end
end
