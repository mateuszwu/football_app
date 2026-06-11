require "rails_helper"

RSpec.describe PlayerSeasonStat do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a player season stat" do
        player_season_stat = build(:player_season_stat)

        expect(player_season_stat).to be_valid
      end
    end

    context "when player is missing" do
      it "is invalid" do
        player_season_stat = described_class.new(player: nil, season: build(:season))

        expect(player_season_stat).not_to be_valid
        expect(player_season_stat.errors[:player]).to include("must exist")
      end
    end

    context "when season is missing" do
      it "is invalid" do
        player_season_stat = described_class.new(player: build(:player), season: nil)

        expect(player_season_stat).not_to be_valid
        expect(player_season_stat.errors[:season]).to include("must exist")
      end
    end

    context "when the player already has stats for the season" do
      it "is invalid" do
        player = create(:player)
        season = create(:season)
        create(:player_season_stat, player: player, season: season)
        player_season_stat = build(:player_season_stat, player: player, season: season)

        expect(player_season_stat).not_to be_valid
        expect(player_season_stat.errors[:player_id]).to include("has already been taken")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a player and season" do
        player_season_stat = create(:player_season_stat)

        expect(player_season_stat.player).to be_present
        expect(player_season_stat.season).to be_present
      end
    end
  end
end
