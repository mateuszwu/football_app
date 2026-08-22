module Voting
  class GenerateMatchDayVoteTokens
    def self.call(match_day:)
      new(match_day:).call
    end

    def initialize(match_day:)
      @match_day = match_day
    end

    def call
      match_day.match_day_players.includes(:match_day_vote_token).find_each do |match_day_player|
        next if match_day_player.match_day_vote_token.present?

        match_day_player.create_match_day_vote_token!(token: generate_token)
      end

      true
    end

    private

    attr_reader :match_day

    def generate_token
      loop do
        token = SecureRandom.urlsafe_base64(32)
        return token unless MatchDayVoteToken.exists?(token:)
      end
    end
  end
end
