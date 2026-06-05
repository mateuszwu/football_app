require "rails_helper"

RSpec.describe MatchDayPlayer do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a match day player" do
        match_day_player = build(:match_day_player)

        expect(match_day_player).to be_valid
      end
    end

    context "when match day is missing" do
      it "is invalid" do
        match_day_player = build(:match_day_player, match_day: nil)

        expect(match_day_player).not_to be_valid
        expect(match_day_player.errors[:match_day]).to include("must exist")
      end
    end

    context "when player is missing" do
      it "is invalid" do
        match_day_player = build(:match_day_player, player: nil)

        expect(match_day_player).not_to be_valid
        expect(match_day_player.errors[:player]).to include("must exist")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a match day and player" do
        match_day = create(:match_day)
        player = create(:player)
        match_day_player = create(:match_day_player, match_day: match_day, player: player)

        expect(match_day_player.match_day).to eq(match_day)
        expect(match_day_player.player).to eq(player)
      end
    end
  end
end
