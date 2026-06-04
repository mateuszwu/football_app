module Api
  class VoteInvitesController < BaseController
    def index
      render json: { vote_invites: vote_invites }
    end

    private

    def vote_invites
      Player.active.order(:name).map do |player|
        {
          phone: player.phone,
          sms_body: sms_body(player)
        }
      end
    end

    def sms_body(player)
      "Czesc #{player.nickname}, zaglosuj na MVP i DEF po dzisiejszym meczu przez swoj link do glosowania."
    end
  end
end
