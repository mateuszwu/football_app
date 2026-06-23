require "rails_helper"

RSpec.describe Seasons::PublicLeaderboardQuery do
  describe ".call" do
    it "returns ranked leaderboards using competition ranking" do
      season = create(:season)
      first_player = create(:player, name: "Adam Nowak", approval_status: "approved", active: true)
      second_player = create(:player, name: "Bartek Nowak", approval_status: "approved", active: true)
      third_player = create(:player, name: "Cezary Nowak", approval_status: "approved", active: true)
      create(:player_season_stat, season:, player: first_player, goals: 5, assists: 1, mvp_votes_count: 2, def_votes_count: 1, elo: 1100)
      create(:player_season_stat, season:, player: second_player, goals: 5, assists: 0, mvp_votes_count: 2, def_votes_count: 1, elo: 1100)
      create(:player_season_stat, season:, player: third_player, goals: 2, assists: 4, mvp_votes_count: 1, def_votes_count: 0, elo: 1000)

      result = described_class.call(season:)

      expect(result.ranked_top_scorers.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.ranked_top_scorers.map(&:value)).to eq([ 5, 5, 2 ])
      expect(result.ranked_top_mvp.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.ranked_elo.map(&:rank)).to eq([ 1, 1, 3 ])
    end
  end
end
