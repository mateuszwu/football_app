module Api
  class MatchDayVoteInvitesController < BaseController
    def show
      match_day = params[:id].present? ? MatchDay.find(params[:id]) : latest_finished_match_day
      vote_invites = Voting::PrepareMatchDayVoteInvites.call(match_day:, base_url: request.base_url)

      render json: { vote_invites: vote_invites }
    end

    private

    def latest_finished_match_day
      Season.current_active&.latest_finished_match_day || raise(ActiveRecord::RecordNotFound)
    end
  end
end
