require "rails_helper"

RSpec.describe Ratings::InitializePlayerSeasonStat do
  describe ".call" do
    it "creates one player season stat per player and season using the carryover formula" do
      season = create(:season, initial_elo: 1000, season_elo_carryover_factor: 0.5)
      player = create(:player, elo: 1200)

      first_result = described_class.call(player:, season:)
      second_result = described_class.call(player:, season:)

      expect(first_result).to eq(second_result)
      expect(first_result.elo).to eq(1100)
      expect(PlayerSeasonStat.where(player:, season:).count).to eq(1)
    end

    it "falls back to the season initial elo when the player has no global elo" do
      season = create(:season, initial_elo: 1000, season_elo_carryover_factor: 0.5)
      player = create(:player, elo: nil)

      result = described_class.call(player:, season:)

      expect(result.elo).to eq(1000)
    end
  end
end
