module Api
  class MatchDayVoteInvitesController < BaseController
    def show
      match_day = MatchDay.find(params[:id])
      Voting::GenerateMatchDayVoteTokens.call(match_day:)

      render json: { vote_invites: vote_invites(match_day) }
    end

    private

    def vote_invites(match_day)
      match_day.match_day_players
               .includes(:match_day_vote_token, :player)
               .filter_map do |match_day_player|
        player = match_day_player.player
        token = match_day_player.match_day_vote_token

        next if player.phone.blank? || token.blank?

        {
          name: player.name,
          phone: player.phone,
          sms_body: sms_body(player:, token:)
        }
      end
    end

    def sms_body(player:, token:)
      "Czesc #{player.name}, zaglosuj na MVP i DEF: #{vote_url(token.token, host: request.base_url)}"
    end
  end
end
