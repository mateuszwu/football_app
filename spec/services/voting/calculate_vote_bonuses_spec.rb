require "rails_helper"

RSpec.describe Voting::CalculateVoteBonuses do
  describe ".call" do
    it "applies MVP and DEF vote bonuses, counts, and performance changes" do
      season = create(:season, mvp_max_points: 4.0, def_max_points: 3.0, voting_bonus_cap: 5.0, expected_voters_count: 5)
      match_day = create(:match_day, season: season, status: "finished")
      first_voter = create(:player, global_performance_score: 0.0)
      second_voter = create(:player, global_performance_score: 0.0)
      mvp_winner = create(:player, global_performance_score: 0.0)
      def_winner = create(:player, global_performance_score: 0.0)
      create(:match_day_player, match_day: match_day, player: first_voter)
      create(:match_day_player, match_day: match_day, player: second_voter)
      create(:match_day_player, match_day: match_day, player: mvp_winner)
      create(:match_day_player, match_day: match_day, player: def_winner)
      first_vote_token = create(:match_day_vote_token, match_day_player: MatchDayPlayer.find_by!(match_day: match_day, player: first_voter))
      second_vote_token = create(:match_day_vote_token, match_day_player: MatchDayPlayer.find_by!(match_day: match_day, player: second_voter))
      MatchDayVote.create!(match_day_vote_token: first_vote_token, mvp_player: mvp_winner, def_player: def_winner)
      MatchDayVote.create!(match_day_vote_token: second_vote_token, mvp_player: mvp_winner, def_player: def_winner)

      described_class.call(match_day: match_day)

      expect(PlayerSeasonStat.find_by!(player: mvp_winner, season: season).attributes.slice("mvp_votes_count", "def_votes_count", "performance_score")).to eq(
        "mvp_votes_count" => 2,
        "def_votes_count" => 0,
        "performance_score" => BigDecimal("1.6")
      )
      expect(PlayerSeasonStat.find_by!(player: def_winner, season: season).attributes.slice("mvp_votes_count", "def_votes_count", "performance_score")).to eq(
        "mvp_votes_count" => 0,
        "def_votes_count" => 2,
        "performance_score" => BigDecimal("1.2")
      )
      expect(mvp_winner.reload.global_performance_score).to eq(BigDecimal("1.6"))
      expect(def_winner.reload.global_performance_score).to eq(BigDecimal("1.2"))
      expect(PlayerRatingChange.find_by!(player: mvp_winner, season: season, match_day: match_day, source_type: PlayerRatingChange::SOURCE_TYPE_VOTE).performance_delta).to eq(BigDecimal("1.6"))
      expect(PlayerRatingChange.find_by!(player: def_winner, season: season, match_day: match_day, source_type: PlayerRatingChange::SOURCE_TYPE_VOTE).performance_delta).to eq(BigDecimal("1.2"))
    end

    it "caps the combined vote bonus using season settings" do
      season = create(:season, mvp_max_points: 4.0, def_max_points: 3.0, voting_bonus_cap: 5.0, expected_voters_count: 1)
      match_day = create(:match_day, season: season, status: "finished")
      voter = create(:player, global_performance_score: 0.0)
      winner = create(:player, global_performance_score: 0.0)
      create(:match_day_player, match_day: match_day, player: voter)
      create(:match_day_player, match_day: match_day, player: winner)
      vote_token = create(:match_day_vote_token, match_day_player: MatchDayPlayer.find_by!(match_day: match_day, player: voter))
      MatchDayVote.create!(match_day_vote_token: vote_token, mvp_player: winner, def_player: winner)

      described_class.call(match_day: match_day)

      expect(PlayerSeasonStat.find_by!(player: winner, season: season).performance_score).to eq(BigDecimal("5.0"))
      expect(PlayerRatingChange.find_by!(player: winner, season: season, match_day: match_day, source_type: PlayerRatingChange::SOURCE_TYPE_VOTE).performance_delta).to eq(BigDecimal("5.0"))
    end

    it "recalculates bonuses idempotently using expected voters normalization" do
      season = create(:season, mvp_max_points: 4.0, def_max_points: 3.0, voting_bonus_cap: 5.0, expected_voters_count: 10)
      match_day = create(:match_day, season: season, status: "finished")
      voter = create(:player, global_performance_score: 0.0)
      winner = create(:player, global_performance_score: 0.0)
      no_votes_player = create(:player, global_performance_score: 0.0)
      create(:match_day_player, match_day: match_day, player: voter)
      create(:match_day_player, match_day: match_day, player: winner)
      create(:match_day_player, match_day: match_day, player: no_votes_player)
      vote_token = create(:match_day_vote_token, match_day_player: MatchDayPlayer.find_by!(match_day: match_day, player: voter))
      MatchDayVote.create!(match_day_vote_token: vote_token, mvp_player: winner, def_player: winner)

      2.times { described_class.call(match_day: match_day) }

      expect(PlayerSeasonStat.find_by!(player: winner, season: season).attributes.slice("mvp_votes_count", "def_votes_count", "performance_score")).to eq(
        "mvp_votes_count" => 1,
        "def_votes_count" => 1,
        "performance_score" => BigDecimal("0.7")
      )
      expect(winner.reload.global_performance_score).to eq(BigDecimal("0.7"))
      expect(PlayerRatingChange.where(player: winner, season: season, match_day: match_day, source_type: PlayerRatingChange::SOURCE_TYPE_VOTE).count).to eq(1)
      expect(PlayerSeasonStat.where(player: no_votes_player, season: season)).to be_empty
      expect(no_votes_player.reload.global_performance_score).to eq(BigDecimal("0.0"))
    end
  end
end
