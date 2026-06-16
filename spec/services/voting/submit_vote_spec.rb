require "rails_helper"

RSpec.describe Voting::SubmitVote do
  describe ".call" do
    it "saves the vote, marks the token used, and recalculates bonuses" do
      season = create(:season, mvp_max_points: 4.0, def_max_points: 3.0, voting_bonus_cap: 5.0, expected_voters_count: 5)
      match_day = create(:match_day, season:)
      voter = create(:player, global_performance_score: 0.0)
      mvp_player = create(:player, global_performance_score: 0.0)
      def_player = create(:player, global_performance_score: 0.0)
      voter_match_day_player = create(:match_day_player, match_day:, player: voter)
      create(:match_day_player, match_day:, player: mvp_player)
      create(:match_day_player, match_day:, player: def_player)
      match_day_vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, used_at: nil)

      vote = described_class.call(
        match_day_vote_token:,
        mvp_player_id: mvp_player.id,
        def_player_id: def_player.id
      )

      expect(vote).to be_persisted
      expect(match_day_vote_token.reload.used_at).to be_present
      expect(PlayerSeasonStat.find_by!(player: mvp_player, season:).performance_score).to eq(BigDecimal("0.8"))
      expect(PlayerSeasonStat.find_by!(player: def_player, season:).performance_score).to eq(BigDecimal("0.6"))
    end

    it "returns an invalid vote without marking the token used" do
      match_day = create(:match_day)
      voter = create(:player)
      candidate = create(:player)
      voter_match_day_player = create(:match_day_player, match_day:, player: voter)
      create(:match_day_player, match_day:, player: candidate)
      match_day_vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, used_at: nil)

      vote = described_class.call(
        match_day_vote_token:,
        mvp_player_id: voter.id,
        def_player_id: candidate.id
      )

      expect(vote).not_to be_persisted
      expect(vote.errors[:mvp_player_id]).to include("cannot be the voter")
      expect(match_day_vote_token.reload.used_at).to be_nil
      expect(match_day_vote_token.match_day_vote).to be_nil
    end
  end
end
