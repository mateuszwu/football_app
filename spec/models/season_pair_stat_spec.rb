require "rails_helper"

RSpec.describe SeasonPairStat do
  describe "validations" do
    it "accepts an ordered player pair with non-negative counters" do
      season = create(:season)
      first_player = create(:player)
      second_player = create(:player)
      player_one, player_two = [ first_player, second_player ].sort_by(&:id)

      pair_stat = described_class.new(
        season:,
        player_one:,
        player_two:,
        shared_match_days_count: 1,
        shared_matches_count: 1
      )

      expect(pair_stat).to be_valid
    end

    it "rejects reversed players and negative counters" do
      season = create(:season)
      first_player = create(:player)
      second_player = create(:player)
      player_one, player_two = [ first_player, second_player ].sort_by(&:id)

      pair_stat = described_class.new(
        season:,
        player_one: player_two,
        player_two: player_one,
        wins: -1
      )

      expect(pair_stat).not_to be_valid
      expect(pair_stat.errors[:player_two_id]).to include("must be greater than player_one_id")
      expect(pair_stat.errors[:wins]).to be_present
    end
  end
end
