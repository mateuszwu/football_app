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

    context "when reroll count is negative" do
      it "is invalid" do
        team_setup = build(:team_setup, reroll_count: -1)

        expect(team_setup).not_to be_valid
        expect(team_setup.errors[:reroll_count]).to include("must be greater than or equal to 0")
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

      it "has many teams" do
        team_setup = create(:team_setup)
        team = create(:team, team_setup: team_setup)

        expect(team_setup.teams).to contain_exactly(team)
      end
    end
  end

  describe "#fingerprint" do
    it "delegates to the fingerprint generator" do
      team_setup = create(:team_setup)
      fingerprint = "abc123"
      allow(TeamSetups::GenerateFingerprint).to receive(:call).with(team_setup: team_setup).and_return(fingerprint)

      result = team_setup.fingerprint

      expect(result).to eq(fingerprint)
      expect(TeamSetups::GenerateFingerprint).to have_received(:call).with(team_setup: team_setup)
    end
  end

  describe "defaults" do
    it "starts with a zero reroll count" do
      team_setup = create(:team_setup)

      expect(team_setup.reroll_count).to eq(0)
    end
  end
end
