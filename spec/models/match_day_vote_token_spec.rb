require "rails_helper"

RSpec.describe MatchDayVoteToken do
  def create_match_day_player_record(name:, season: create(:season), played_on: Date.new(2026, 6, 5), status: "finished")
    match_day = create(:match_day, season:, played_on:, status:)
    player = create(:player, name:)

    MatchDayPlayer.create!(match_day:, player:)
  end

  describe "validations" do
    context "when required attributes are present" do
      it "creates a match day vote token" do
        match_day_vote_token = described_class.new(match_day_player: MatchDayPlayer.new, token: "vote-token-1")

        expect(match_day_vote_token).to be_valid
      end
    end

    context "when match day player is missing" do
      it "is invalid" do
        match_day_vote_token = described_class.new(match_day_player: nil, token: "vote-token-1")

        expect(match_day_vote_token).not_to be_valid
        expect(match_day_vote_token.errors[:match_day_player]).to include("must exist")
      end
    end

    context "when token is missing" do
      it "is invalid" do
        match_day_vote_token = described_class.new(match_day_player: MatchDayPlayer.new, token: nil)

        expect(match_day_vote_token).not_to be_valid
        expect(match_day_vote_token.errors[:token]).to include("can't be blank")
      end
    end

    context "when token is duplicated" do
      it "is invalid" do
        first_match_day_player = create_match_day_player_record(name: "Player One")
        second_match_day_player = create_match_day_player_record(name: "Player Two")
        described_class.create!(match_day_player: first_match_day_player, token: "shared-token")
        match_day_vote_token = described_class.new(match_day_player: second_match_day_player, token: "shared-token")

        expect(match_day_vote_token).not_to be_valid
        expect(match_day_vote_token.errors[:token]).to include("has already been taken")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a match day player" do
        match_day_player = create_match_day_player_record(name: "Player Three")
        match_day_vote_token = described_class.create!(match_day_player:, token: "vote-token-3")

        expect(match_day_vote_token.match_day_player).to eq(match_day_player)
      end

      it "can have a match day vote" do
        match_day_player = create_match_day_player_record(name: "Player Four")
        match_day_vote_token = described_class.create!(match_day_player:, token: "vote-token-4")
        mvp_player = create(:player, name: "Assoc MVP")
        def_player = create(:player, name: "Assoc DEF")
        create(:match_day_player, match_day: match_day_player.match_day, player: mvp_player)
        create(:match_day_player, match_day: match_day_player.match_day, player: def_player)
        match_day_vote = MatchDayVote.create!(
          match_day_vote_token:,
          mvp_player:,
          def_player:
        )

        expect(match_day_vote_token.match_day_vote).to eq(match_day_vote)
      end
    end
  end

  describe "database columns" do
    it "stores the token usage timestamp without a fixed expiry timestamp" do
      expect(described_class.columns_hash["used_at"].type).to eq(:datetime)
      expect(described_class.columns_hash).not_to have_key("expires_at")
    end
  end

  describe "#expired?" do
    context "when the token belongs to the latest finished match day" do
      it "returns false even when a newer match day is scheduled" do
        season = create(:season)
        match_day_player = create_match_day_player_record(
          name: "Current Player",
          season:,
          played_on: Date.new(2026, 6, 5)
        )
        create(:match_day, season:, played_on: Date.new(2026, 6, 12), status: "ready")
        match_day_vote_token = create(:match_day_vote_token, match_day_player:)

        result = match_day_vote_token.expired?

        expect(result).to be(false)
      end
    end

    context "when a newer finished match day exists" do
      it "returns true" do
        season = create(:season)
        match_day_player = create_match_day_player_record(
          name: "Previous Player",
          season:,
          played_on: Date.new(2026, 6, 5)
        )
        create(:match_day, season:, played_on: Date.new(2026, 6, 12), status: "finished")
        match_day_vote_token = create(:match_day_vote_token, match_day_player:)

        result = match_day_vote_token.expired?

        expect(result).to be(true)
      end
    end

    context "when the token match day is not finished" do
      it "returns true" do
        match_day_player = create_match_day_player_record(name: "Scheduled Player", status: "ready")
        match_day_vote_token = create(:match_day_vote_token, match_day_player:)

        result = match_day_vote_token.expired?

        expect(result).to be(true)
      end
    end
  end
end
