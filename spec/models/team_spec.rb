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

    context "when lineup source is missing" do
      it "is invalid" do
        team = build(:team, lineup_source: nil)

        expect(team).not_to be_valid
        expect(team.errors[:lineup_source]).to include("can't be blank")
      end
    end

    context "when lineup source is unsupported" do
      it "is invalid" do
        team = build(:team, lineup_source: "legacy")

        expect(team).not_to be_valid
        expect(team.errors[:lineup_source]).to include("is not included in the list")
      end
    end

    context "when score is negative" do
      it "is invalid" do
        team = build(:team, score: -1)

        expect(team).not_to be_valid
        expect(team.errors[:score]).to include("must be greater than or equal to 0")
      end
    end

    context "when result is supported" do
      it "is valid" do
        teams = Team::RESULTS.map { |result| build(:team, result: result) }

        expect(teams).to all(be_valid)
      end
    end

    context "when result is unsupported" do
      it "is invalid" do
        team = build(:team, result: "cancelled")

        expect(team).not_to be_valid
        expect(team.errors[:result]).to include("is not included in the list")
      end
    end

    context "when captain is missing" do
      it "is valid" do
        team = create(:team, captain: nil)

        expect(team).to be_valid
      end
    end

    context "when captain belongs to the roster" do
      it "is valid" do
        team = create(:team)
        player = create(:player)
        create(:team_player, team:, player:)

        team.captain = player

        expect(team).to be_valid
      end
    end

    context "when captain does not belong to the roster" do
      it "is invalid" do
        team = create(:team)
        player = create(:player)

        team.captain = player

        expect(team).not_to be_valid
        expect(team.errors[:captain_id]).to include("musi nalezec do tej druzyny")
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

      it "can belong to a match" do
        match = create(:match)
        team = create(:team, match: match)

        expect(team.match).to eq(match)
      end

      it "has many team players" do
        team = create(:team)
        team_player = create(:team_player, team: team)

        expect(team.team_players).to contain_exactly(team_player)
      end

      it "has many players through team players" do
        team = create(:team)
        player = create(:player)
        create(:team_player, team: team, player: player)

        expect(team.players).to contain_exactly(player)
      end

      it "can reference a source team" do
        source_team = create(:team)
        team = create(:team, source_team: source_team)

        expect(team.source_team).to eq(source_team)
        expect(source_team.derived_teams).to include(team)
      end
    end
  end

  describe "#fingerprint" do
    it "delegates to the team fingerprint generator" do
      team = create(:team)
      fingerprint = "1-2-3"
      allow(Teams::GenerateFingerprint).to receive(:call).with(team: team).and_return(fingerprint)

      result = team.fingerprint

      expect(result).to eq(fingerprint)
      expect(Teams::GenerateFingerprint).to have_received(:call).with(team: team)
    end
  end

  describe "#modified_from_source?" do
    it "returns false when there is no source team" do
      team = create(:team)

      expect(team.modified_from_source?).to be(false)
    end

    it "returns false when the source team has the same player fingerprint" do
      source_team = create(:team)
      team = create(:team, source_team: source_team)
      player_one = create(:player)
      player_two = create(:player, nickname: "player-two", phone: "+48123000999")

      create(:team_player, team: source_team, player: player_two)
      create(:team_player, team: source_team, player: player_one)
      create(:team_player, team: team, player: player_one)
      create(:team_player, team: team, player: player_two)

      expect(team.modified_from_source?).to be(false)
    end

    it "returns true when the source team has a different player fingerprint" do
      source_team = create(:team)
      team = create(:team, source_team: source_team)
      shared_player = create(:player)
      source_only_player = create(:player, nickname: "source-only", phone: "+48123000998")
      current_only_player = create(:player, nickname: "current-only", phone: "+48123000997")

      create(:team_player, team: source_team, player: shared_player)
      create(:team_player, team: source_team, player: source_only_player)
      create(:team_player, team: team, player: shared_player)
      create(:team_player, team: team, player: current_only_player)

      expect(team.modified_from_source?).to be(true)
    end
  end
end
