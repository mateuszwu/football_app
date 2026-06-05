require "rails_helper"

RSpec.describe TeamPlayer do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a team player" do
        team_player = build(:team_player)

        expect(team_player).to be_valid
      end
    end

    context "when team is missing" do
      it "is invalid" do
        team_player = build(:team_player, team: nil)

        expect(team_player).not_to be_valid
        expect(team_player.errors[:team]).to include("must exist")
      end
    end

    context "when player is missing" do
      it "is invalid" do
        team_player = build(:team_player, player: nil)

        expect(team_player).not_to be_valid
        expect(team_player.errors[:player]).to include("must exist")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a team" do
        team = create(:team)
        team_player = create(:team_player, team: team)

        expect(team_player.team).to eq(team)
      end

      it "belongs to a player" do
        player = create(:player)
        team_player = create(:team_player, player: player)

        expect(team_player.player).to eq(player)
      end
    end
  end
end
