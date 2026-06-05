require "rails_helper"

RSpec.describe Team do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a team" do
        team = build(:team)

        expect(team).to be_valid
      end
    end

    context "when team setup is missing" do
      it "is invalid" do
        team = build(:team, team_setup: nil)

        expect(team).not_to be_valid
        expect(team.errors[:team_setup]).to include("must exist")
      end
    end

    context "when name is missing" do
      it "is invalid" do
        team = build(:team, name: nil)

        expect(team).not_to be_valid
        expect(team.errors[:name]).to include("can't be blank")
      end
    end

    context "when team type is supported" do
      it "is valid" do
        teams = Team::TEAM_TYPES.map { |team_type| build(:team, team_type: team_type) }

        expect(teams).to all(be_valid)
      end
    end

    context "when team type is missing" do
      it "is invalid" do
        team = build(:team, team_type: nil)

        expect(team).not_to be_valid
        expect(team.errors[:team_type]).to include("can't be blank")
      end
    end

    context "when team type is unsupported" do
      it "is invalid" do
        team = build(:team, team_type: "playoff")

        expect(team).not_to be_valid
        expect(team.errors[:team_type]).to include("is not included in the list")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a team setup" do
        team_setup = create(:team_setup)
        team = create(:team, team_setup: team_setup)

        expect(team.team_setup).to eq(team_setup)
      end
    end
  end
end
