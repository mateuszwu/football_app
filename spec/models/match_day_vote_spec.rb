require "rails_helper"

RSpec.describe MatchDayVote do
  def create_vote_token(name:)
    season = create(:season)
    match_day = create(:match_day, season: season)
    player = create(:player, name: name)
    match_day_player = MatchDayPlayer.create!(match_day: match_day, player: player)

    MatchDayVoteToken.create!(match_day_player: match_day_player, token: "#{name.parameterize}-token")
  end

  describe "validations" do
    context "when required attributes are present" do
      it "creates a match day vote" do
        match_day_vote_token = create_vote_token(name: "Voter")
        mvp_player = create(:player, name: "MVP Player")
        def_player = create(:player, name: "DEF Player")
        match_day_vote = described_class.new(
          match_day_vote_token: match_day_vote_token,
          mvp_player: mvp_player,
          def_player: def_player
        )

        expect(match_day_vote).to be_valid
      end
    end

    context "when vote token is missing" do
      it "is invalid" do
        mvp_player = Player.new
        def_player = Player.new
        match_day_vote = described_class.new(match_day_vote_token: nil, mvp_player: mvp_player, def_player: def_player)

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:match_day_vote_token]).to include("must exist")
      end
    end

    context "when mvp player is missing" do
      it "is invalid" do
        match_day_vote = described_class.new(match_day_vote_token: MatchDayVoteToken.new, mvp_player: nil, def_player: Player.new)

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:mvp_player]).to include("must exist")
      end
    end

    context "when def player is missing" do
      it "is invalid" do
        match_day_vote = described_class.new(match_day_vote_token: MatchDayVoteToken.new, mvp_player: Player.new, def_player: nil)

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:def_player]).to include("must exist")
      end
    end

    context "when the vote token already has a vote" do
      it "is invalid" do
        match_day_vote_token = create_vote_token(name: "Voter One")
        first_mvp_player = create(:player, name: "First MVP")
        first_def_player = create(:player, name: "First DEF")
        second_mvp_player = create(:player, name: "Second MVP")
        second_def_player = create(:player, name: "Second DEF")
        described_class.create!(
          match_day_vote_token: match_day_vote_token,
          mvp_player: first_mvp_player,
          def_player: first_def_player
        )
        match_day_vote = described_class.new(
          match_day_vote_token: match_day_vote_token,
          mvp_player: second_mvp_player,
          def_player: second_def_player
        )

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:match_day_vote_token_id]).to include("has already been taken")
      end
    end

    context "when the voter selects themself as MVP" do
      it "is invalid" do
        match_day_vote_token = create_vote_token(name: "Voter Self")
        def_player = create(:player, name: "Other DEF")
        match_day_vote = described_class.new(
          match_day_vote_token: match_day_vote_token,
          mvp_player: match_day_vote_token.match_day_player.player,
          def_player: def_player
        )

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:mvp_player_id]).to include("cannot be the voter")
      end
    end

    context "when the voter selects themself as DEF" do
      it "is invalid" do
        match_day_vote_token = create_vote_token(name: "Voter Self")
        mvp_player = create(:player, name: "Other MVP")
        match_day_vote = described_class.new(
          match_day_vote_token: match_day_vote_token,
          mvp_player: mvp_player,
          def_player: match_day_vote_token.match_day_player.player
        )

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:def_player_id]).to include("cannot be the voter")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to the vote token and selected players" do
        match_day_vote_token = create_vote_token(name: "Voter Two")
        mvp_player = create(:player, name: "Winner MVP")
        def_player = create(:player, name: "Winner DEF")
        match_day_vote = described_class.create!(
          match_day_vote_token: match_day_vote_token,
          mvp_player: mvp_player,
          def_player: def_player
        )

        expect(match_day_vote.match_day_vote_token).to eq(match_day_vote_token)
        expect(match_day_vote.mvp_player).to eq(mvp_player)
        expect(match_day_vote.def_player).to eq(def_player)
      end
    end
  end
end
