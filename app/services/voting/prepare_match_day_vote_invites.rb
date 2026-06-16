module Voting
  class PrepareMatchDayVoteInvites
    def self.call(match_day:, base_url:)
      new(match_day:, base_url:).call
    end

    def initialize(match_day:, base_url:)
      @match_day = match_day
      @base_url = base_url
    end

    def call
      Voting::GenerateMatchDayVoteTokens.call(match_day:)

      match_day.match_day_players
               .includes(:match_day_vote_token, :player)
               .filter_map do |match_day_player|
        build_invite(match_day_player)
      end
    end

    private

    attr_reader :base_url, :match_day

    def build_invite(match_day_player)
      player = match_day_player.player
      token = match_day_player.match_day_vote_token

      return if player.phone.blank? || token.blank?

      {
        name: player.name,
        phone: player.phone,
        sms_body: sms_body(player:, token:)
      }
    end

    def sms_body(player:, token:)
      "Czesc #{player.name}, zaglosuj na MVP i DEF: #{vote_url(token.token, host: base_url)}"
    end

    def vote_url(token, host:)
      Rails.application.routes.url_helpers.vote_url(token, host:)
    end
  end
end
