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
        season = build(:season)
        match_day = build(:match_day, season: season)
        player_rating_change = described_class.new(season: season, match_day: match_day, rating_scope: "season", source_type: "match", reason: "match_elo", old_elo_score: 1000, new_elo_score: 1016, elo_delta: 16)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:player]).to include("must exist")
      end
    end

    context "when season is missing" do
      it "is invalid" do
        player_rating_change = described_class.new(player: build(:player), match_day: build(:match_day), rating_scope: "season", source_type: "match", reason: "match_elo", old_elo_score: 1000, new_elo_score: 1016, elo_delta: 16)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:season]).to include("must exist")
      end
    end

    context "when old_elo_score is missing for an Elo change" do
      it "is invalid" do
        player_rating_change = build(:player_rating_change, old_elo_score: nil)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:old_elo_score]).to include("can't be blank")
      end
    end

    context "when new_elo_score is missing for an Elo change" do
      it "is invalid" do
        player_rating_change = build(:player_rating_change, new_elo_score: nil)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:new_elo_score]).to include("can't be blank")
      end
    end

    context "when elo_delta is missing for an Elo change" do
      it "is invalid" do
        player_rating_change = build(:player_rating_change, elo_delta: nil)

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:elo_delta]).to include("can't be blank")
      end
    end

    context "when performance_delta is missing for a performance change" do
      it "is invalid" do
        player_rating_change = build(
          :player_rating_change,
          source_type: PlayerRatingChange::SOURCE_TYPE_GOAL,
          reason: "goal_performance",
          old_elo_score: nil,
          elo_delta: nil,
          new_elo_score: nil,
          performance_delta: nil,
          elo_k_value: nil,
          player_advantage_elo: nil
        )

        expect(player_rating_change).not_to be_valid
        expect(player_rating_change.errors[:performance_delta]).to include("can't be blank")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a player and season" do
        player_rating_change = create(:player_rating_change)

        expect(player_rating_change.player).to be_present
        expect(player_rating_change.season).to be_present
        expect(player_rating_change.match_day).to be_present
      end

      it "can belong to a match" do
        match = create(:match)
        player_rating_change = create(:player_rating_change, season: match.match_day.season, match_day: match.match_day, match: match)

        expect(player_rating_change.match).to eq(match)
      end
    end
  end
end
