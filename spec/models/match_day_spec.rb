require "rails_helper"

RSpec.describe MatchDay do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a match day" do
        match_day = build(:match_day)

        expect(match_day).to be_valid
      end
    end

    context "when season is missing" do
      it "is invalid" do
        match_day = build(:match_day, season: nil)

        expect(match_day).not_to be_valid
        expect(match_day.errors[:season]).to include("must exist")
      end
    end

    context "when played_on is missing" do
      it "is invalid" do
        match_day = build(:match_day, played_on: nil)

        expect(match_day).not_to be_valid
        expect(match_day.errors[:played_on]).to include("can't be blank")
      end
    end

    context "when status is supported" do
      it "is valid" do
        match_days = MatchDay::STATUSES.map { |status| build(:match_day, status: status) }

        expect(match_days).to all(be_valid)
      end
    end

    context "when status is unsupported" do
      it "is invalid" do
        match_day = build(:match_day, status: "archived")

        expect(match_day).not_to be_valid
        expect(match_day.errors[:status]).to include("is not included in the list")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a season" do
        season = create(:season)
        match_day = create(:match_day, season: season)

        expect(match_day.season).to eq(season)
      end

      it "has many team setups" do
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day: match_day)

        expect(match_day.team_setups).to contain_exactly(team_setup)
      end
    end
  end
end
