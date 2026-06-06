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

    context "when the status skips the allowed transition path" do
      it "is invalid" do
        match_day = create(:match_day, status: "setup")
        match_day.status = "finished"

        expect(match_day).not_to be_valid
        expect(match_day.errors[:status]).to include("cannot transition from setup to finished")
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

      it "has many teams through team setups" do
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day: match_day)
        team = create(:team, team_setup: team_setup)

        expect(match_day.teams).to contain_exactly(team)
      end
    end
  end

  describe "#ready_for_match?" do
    context "when all selected players are assigned across Team A and Team B" do
      it "returns true" do
        match_day = create(:match_day)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        create(:match_day_player, match_day:, player: first_player)
        create(:match_day_player, match_day:, player: second_player)
        team_setup = create(:team_setup, match_day:)
        team_a = create(:team, team_setup:, name: "Team A", team_type: "baseline")
        team_b = create(:team, team_setup:, name: "Team B", team_type: "baseline")
        create(:team_player, team: team_a, player: first_player)
        create(:team_player, team: team_b, player: second_player)

        result = match_day.ready_for_match?

        expect(result).to be(true)
      end
    end

    context "when not all selected players are assigned to baseline teams" do
      it "returns false" do
        match_day = create(:match_day)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        create(:match_day_player, match_day:, player: first_player)
        create(:match_day_player, match_day:, player: second_player)
        team_setup = create(:team_setup, match_day:)
        team_a = create(:team, team_setup:, name: "Team A", team_type: "baseline")
        create(:team_player, team: team_a, player: first_player)

        result = match_day.ready_for_match?

        expect(result).to be(false)
      end
    end
  end
end
