require "rails_helper"

RSpec.describe MatchDayVote do
  def create_vote_token(name:)
    season = create(:season)
    match_day = create(:match_day, season:, status: "finished")
    player = create(:player, name:)
    match_day_player = MatchDayPlayer.create!(match_day:, player:)

    MatchDayVoteToken.create!(match_day_player:, token: "#{name.parameterize}-token")
  end

  def add_player_to_match_day(match_day_vote_token:, player:)
    create(:match_day_player, match_day: match_day_vote_token.match_day_player.match_day, player:)
  end

  describe "validations" do
    context "when required attributes are present" do
      it "creates a match day vote" do
        match_day_vote_token = create_vote_token(name: "Voter")
        mvp_player = create(:player, name: "MVP Player")
        def_player = create(:player, name: "DEF Player")
        add_player_to_match_day(match_day_vote_token:, player: mvp_player)
        add_player_to_match_day(match_day_vote_token:, player: def_player)
        match_day_vote = described_class.new(
          match_day_vote_token:,
          mvp_player:,
          def_player:
        )

        expect(match_day_vote).to be_valid
        expect(match_day_vote.submitted_at).to be_present
      end
    end

    context "when vote token is missing" do
      it "is invalid" do
        mvp_player = Player.new
        def_player = Player.new
        match_day_vote = described_class.new(match_day_vote_token: nil, mvp_player:, def_player:)

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
        [ first_mvp_player, first_def_player, second_mvp_player, second_def_player ].each do |player|
          add_player_to_match_day(match_day_vote_token:, player:)
        end
        described_class.create!(
          match_day_vote_token:,
          mvp_player: first_mvp_player,
          def_player: first_def_player
        )
        match_day_vote = described_class.new(
          match_day_vote_token:,
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
        add_player_to_match_day(match_day_vote_token:, player: def_player)
        match_day_vote = described_class.new(
          match_day_vote_token:,
          mvp_player: match_day_vote_token.match_day_player.player,
          def_player:
        )

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:mvp_player_id]).to include("cannot be the voter")
      end
    end

    context "when the voter selects themself as DEF" do
      it "is invalid" do
        match_day_vote_token = create_vote_token(name: "Voter Self")
        mvp_player = create(:player, name: "Other MVP")
        add_player_to_match_day(match_day_vote_token:, player: mvp_player)
        match_day_vote = described_class.new(
          match_day_vote_token:,
          mvp_player:,
          def_player: match_day_vote_token.match_day_player.player
        )

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:def_player_id]).to include("cannot be the voter")
      end
    end

    context "when a selected player did not participate in the match day" do
      it "is invalid" do
        match_day_vote_token = create_vote_token(name: "Voter Outside")
        outside_player = create(:player, name: "Outside MVP")
        def_player = create(:player, name: "Present DEF")
        add_player_to_match_day(match_day_vote_token:, player: def_player)
        match_day_vote = described_class.new(
          match_day_vote_token:,
          mvp_player: outside_player,
          def_player:
        )

        expect(match_day_vote).not_to be_valid
        expect(match_day_vote.errors[:mvp_player_id]).to include("must belong to the match day")
      end
    end

    context "when the same non-voter is selected for MVP and DEF" do
      it "is valid" do
        match_day_vote_token = create_vote_token(name: "Voter Same")
        selected_player = create(:player, name: "Two Way Player")
        add_player_to_match_day(match_day_vote_token:, player: selected_player)
        match_day_vote = described_class.new(
          match_day_vote_token:,
          mvp_player: selected_player,
          def_player: selected_player
        )

        expect(match_day_vote).to be_valid
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to the vote token and selected players" do
        match_day_vote_token = create_vote_token(name: "Voter Two")
        mvp_player = create(:player, name: "Winner MVP")
        def_player = create(:player, name: "Winner DEF")
        add_player_to_match_day(match_day_vote_token:, player: mvp_player)
        add_player_to_match_day(match_day_vote_token:, player: def_player)
        match_day_vote = described_class.create!(
          match_day_vote_token:,
          mvp_player:,
          def_player:
        )

        expect(match_day_vote.match_day_vote_token).to eq(match_day_vote_token)
        expect(match_day_vote.mvp_player).to eq(mvp_player)
        expect(match_day_vote.def_player).to eq(def_player)
      end
    end
  end
end
