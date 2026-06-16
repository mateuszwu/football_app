module Api
  class MatchDayVoteInvitesController < BaseController
    def show
      match_day = MatchDay.find(params[:id])
      vote_invites = Voting::PrepareMatchDayVoteInvites.call(match_day:, base_url: request.base_url)

      render json: { vote_invites: vote_invites }
    end
  end
end
