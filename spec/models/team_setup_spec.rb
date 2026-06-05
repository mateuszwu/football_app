require "rails_helper"

RSpec.describe TeamSetup do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a team setup" do
        team_setup = build(:team_setup)

        expect(team_setup).to be_valid
      end
    end

    context "when match day is missing" do
      it "is invalid" do
        team_setup = build(:team_setup, match_day: nil)

        expect(team_setup).not_to be_valid
        expect(team_setup.errors[:match_day]).to include("must exist")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a match day" do
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day: match_day)

        expect(team_setup.match_day).to eq(match_day)
      end
    end
  end
end
