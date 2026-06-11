require "rails_helper"

RSpec.describe PlayerRatingChange do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a player rating change" do
        player_rating_change = build(:player_rating_change)

        expect(player_rating_change).to be_valid
      end
    end

    context "when player is missing" do
      it "is invalid" do
        player_rating_change = described_class.new(season: build(:season), elo_before: 1000, elo_after: 1016, delta: 16)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:player]).to include("must exist")
      end
    end

    context "when season is missing" do
      it "is invalid" do
        player_rating_change = described_class.new(player: build(:player), elo_before: 1000, elo_after: 1016, delta: 16)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:season]).to include("must exist")
      end
    end

    context "when elo_before is missing" do
      it "is invalid" do
        player_rating_change = build(:player_rating_change, elo_before: nil)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:elo_before]).to include("can't be blank")
      end
    end

    context "when elo_after is missing" do
      it "is invalid" do
        player_rating_change = build(:player_rating_change, elo_after: nil)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:elo_after]).to include("can't be blank")
      end
    end

    context "when delta is missing" do
      it "is invalid" do
        player_rating_change = build(:player_rating_change, delta: nil)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:delta]).to include("can't be blank")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a player and season" do
        player_rating_change = create(:player_rating_change)

        expect(player_rating_change.player).to be_present
        expect(player_rating_change.season).to be_present
      end

      it "can belong to a match" do
        match = create(:match)
        player_rating_change = create(:player_rating_change, season: match.match_day.season, match: match)

        expect(player_rating_change.match).to eq(match)
      end
    end
  end
end
