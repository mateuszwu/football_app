module Api
  class VoteInvitesController < BaseController
    def index
      render json: { vote_invites: [] }
    end
  end
end
