module Api
  class VoteInvitesController < BaseController
    def index
      render json: { vote_invites: vote_invites }
    end

    private

    def vote_invites
      return [] if invite_params[:phone].blank? || invite_params[:sms_body].blank?

      [
        {
          phone: invite_params[:phone],
          sms_body: invite_params[:sms_body]
        }
      ]
    end

    def invite_params
      params.permit(:phone, :sms_body)
    end
  end
end
