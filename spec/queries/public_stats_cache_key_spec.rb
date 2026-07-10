require "rails_helper"

RSpec.describe PublicStats::CacheKey do
  describe ".season" do
    it "changes when tracked season data changes" do
      season = create(:season)
      initial_key = described_class.season(season)

      create(:match_day, season:)

      expect(described_class.season(season)).not_to eq(initial_key)
    end

    it "does not change for match days from another season" do
      season = create(:season)
      other_season = create(:season)
      initial_key = described_class.season(season)

      create(:match_day, season: other_season)

      expect(described_class.season(season)).to eq(initial_key)
    end
  end

  describe ".global" do
    it "changes when any tracked public data changes" do
      initial_key = described_class.global

      create(:player, approval_status: "approved")

      expect(described_class.global).not_to eq(initial_key)
    end
  end
end
