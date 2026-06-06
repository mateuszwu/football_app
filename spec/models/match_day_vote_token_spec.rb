require "rails_helper"

RSpec.describe MatchDayVoteToken do
  def create_persisted_player(name:)
    attributes = {
      name: name,
      role_code: "ANY",
      description: "Regular football player",
      approval_status: "pending",
      active: true,
      created_at: Time.current,
      updated_at: Time.current
    }

    if Player.columns_hash.key?("nickname")
      attributes[:nickname] = name.parameterize
    end

    if Player.columns_hash.key?("phone")
      attributes[:phone] = "+48123#{SecureRandom.random_number(10**6).to_s.rjust(6, "0")}"
    end

    if Player.columns_hash.key?("rating_code")
      attributes[:rating_code] = "starter"
    end

    if Player.columns_hash.key?("team_id")
      attributes[:team_id] = nil
    end

    Player.insert(attributes)

    Player.order(:id).last
  end

  def create_match_day_player_record(name:)
    season = create(:season)
    match_day = create(:match_day, season: season)
    player = create_persisted_player(name: name)

    MatchDayPlayer.create!(match_day: match_day, player: player)
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
        match_day_vote_token = described_class.create!(match_day_player: match_day_player, token: "vote-token-3")

        expect(match_day_vote_token.match_day_player).to eq(match_day_player)
      end

      it "can have a match day vote" do
        match_day_vote_token = create_match_day_player_record(name: "Player Four").then do |match_day_player|
          described_class.create!(match_day_player: match_day_player, token: "vote-token-4")
        end
        mvp_player = create_persisted_player(name: "Assoc MVP")
        def_player = create_persisted_player(name: "Assoc DEF")
        match_day_vote = MatchDayVote.create!(
          match_day_vote_token: match_day_vote_token,
          mvp_player: mvp_player,
          def_player: def_player
        )

        expect(match_day_vote_token.match_day_vote).to eq(match_day_vote)
      end
    end
  end

  describe "database columns" do
    it "stores the token usage timestamp" do
      expect(described_class.columns_hash["used_at"].type).to eq(:datetime)
    end
  end
end
