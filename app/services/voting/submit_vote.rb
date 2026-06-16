module Voting
  class SubmitVote
    def self.call(match_day_vote_token:, mvp_player_id:, def_player_id:)
      new(
        match_day_vote_token:,
        mvp_player_id:,
        def_player_id:
      ).call
    end

    def initialize(match_day_vote_token:, mvp_player_id:, def_player_id:)
      @match_day_vote_token = match_day_vote_token
      @mvp_player_id = mvp_player_id
      @def_player_id = def_player_id
    end

    def call
      vote.assign_attributes(
        match_day_vote_token:,
        mvp_player_id:,
        def_player_id:
      )

      return vote unless vote.valid?

      MatchDayVote.transaction do
        vote.save!
        match_day_vote_token.mark_used!
        Voting::CalculateVoteBonuses.call(match_day:)
      end

      vote
    end

    private

    attr_reader :match_day_vote_token, :mvp_player_id, :def_player_id

    def vote
      @vote ||= match_day_vote_token.match_day_vote || MatchDayVote.new(match_day_vote_token:)
    end

    def match_day
      match_day_vote_token.match_day_player.match_day
    end
  end
end
