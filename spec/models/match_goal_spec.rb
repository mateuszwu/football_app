require "rails_helper"

RSpec.describe MatchGoal do
  describe "validations" do
    context "when required attributes are present" do
      it "is valid" do
        match = create(:match)
        scorer = create(:player)
        create(:team_player, team: match.home_team, player: scorer)

        goal = build(:match_goal, match: match, scoring_team: match.home_team, scorer: scorer)

        expect(goal).to be_valid
      end
    end

    context "when assistant is present and valid" do
      it "is valid" do
        match = create(:match)
        scorer = create(:player)
        assistant = create(:player)
        create(:team_player, team: match.home_team, player: scorer)
        create(:team_player, team: match.home_team, player: assistant)

        goal = build(:match_goal, match: match, scoring_team: match.home_team, scorer: scorer, assistant: assistant)

        expect(goal).to be_valid
      end
    end

    context "when assistant is the scorer" do
      it "is invalid" do
        match = create(:match)
        scorer = create(:player)
        create(:team_player, team: match.home_team, player: scorer)

        goal = build(:match_goal, match: match, scoring_team: match.home_team, scorer: scorer, assistant: scorer)

        expect(goal).not_to be_valid
        expect(goal.errors[:assistant]).to include("cannot be the scorer")
      end
    end

    context "when assistant belongs to a different team" do
      it "is invalid" do
        match = create(:match)
        scorer = create(:player)
        assistant = create(:player)
        create(:team_player, team: match.home_team, player: scorer)
        create(:team_player, team: match.away_team, player: assistant)

        goal = build(:match_goal, match: match, scoring_team: match.home_team, scorer: scorer, assistant: assistant)

        expect(goal).not_to be_valid
        expect(goal.errors[:assistant]).to include("must belong to the scoring team")
      end
    end
  end

  describe ".active" do
    it "returns only goals that were not undone" do
      match = create(:match)
      scorer = create(:player)
      create(:team_player, team: match.home_team, player: scorer)
      active_goal = create(:match_goal, match:, scoring_team: match.home_team, scorer:, scored_at: Time.zone.now)
      create(:match_goal, match:, scoring_team: match.home_team, scorer:, scored_at: 1.minute.from_now, undone_at: Time.zone.now)

      result = described_class.active

      expect(result).to contain_exactly(active_goal)
    end
  end
end
