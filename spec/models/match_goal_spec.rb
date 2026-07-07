require "rails_helper"

RSpec.describe MatchGoal do
  describe "validations" do
    context "when required attributes are present" do
      it "is valid" do
        match = create(:match)
        scorer = create(:player)
        scorer_team_player = create(:team_player, team: match.home_team, player: scorer)

        goal = build(:match_goal, match: match, scoring_team: match.home_team, scorer_team_player: scorer_team_player)

        expect(goal).to be_valid
      end
    end

    context "when assistant is present and valid" do
      it "is valid" do
        match = create(:match)
        scorer = create(:player)
        assistant = create(:player)
        scorer_team_player = create(:team_player, team: match.home_team, player: scorer)
        assistant_team_player = create(:team_player, team: match.home_team, player: assistant)

        goal = build(
          :match_goal,
          match: match,
          scoring_team: match.home_team,
          scorer_team_player: scorer_team_player,
          assistant_team_player: assistant_team_player
        )

        expect(goal).to be_valid
      end
    end

    context "when the goal is an own goal by an opponent" do
      it "is valid" do
        match = create(:match)
        scorer_team_player = create(:team_player, team: match.away_team, player: create(:player))

        goal = build(:match_goal, match:, scoring_team: match.home_team, scorer_team_player:, own_goal: true)

        expect(goal).to be_valid
      end
    end

    context "when assistant is the scorer" do
      it "is invalid" do
        match = create(:match)
        scorer = create(:player)
        scorer_team_player = create(:team_player, team: match.home_team, player: scorer)

        goal = build(
          :match_goal,
          match: match,
          scoring_team: match.home_team,
          scorer_team_player: scorer_team_player,
          assistant_team_player: scorer_team_player
        )

        expect(goal).not_to be_valid
        expect(goal.errors[:assistant_team_player]).to include("cannot be the scorer")
      end
    end

    context "when assistant belongs to a different team" do
      it "is invalid" do
        match = create(:match)
        scorer = create(:player)
        assistant = create(:player)
        scorer_team_player = create(:team_player, team: match.home_team, player: scorer)
        assistant_team_player = create(:team_player, team: match.away_team, player: assistant)

        goal = build(
          :match_goal,
          match: match,
          scoring_team: match.home_team,
          scorer_team_player: scorer_team_player,
          assistant_team_player: assistant_team_player
        )

        expect(goal).not_to be_valid
        expect(goal.errors[:assistant_team_player]).to include("must belong to the scoring team")
      end
    end

    context "when the scoring team is not playing" do
      it "is invalid" do
        match = create(:match)
        waiting_team = create(:team, team_setup: match.home_team.team_setup, match: match, name: "Waiting", team_type: Team::TEAM_TYPE_MATCH, playing: false)
        scorer_team_player = create(:team_player, team: waiting_team, player: create(:player))

        goal = build(:match_goal, match: match, scoring_team: waiting_team, scorer_team_player: scorer_team_player)

        expect(goal).not_to be_valid
        expect(goal.errors[:scoring_team]).to include("must be a playing team")
      end
    end

    context "when an own goal scorer belongs to the scoring team" do
      it "is invalid" do
        match = create(:match)
        scorer_team_player = create(:team_player, team: match.home_team, player: create(:player))

        goal = build(:match_goal, match:, scoring_team: match.home_team, scorer_team_player:, own_goal: true)

        expect(goal).not_to be_valid
        expect(goal.errors[:scorer_team_player]).to include("must belong to the opponent for an own goal")
      end
    end

    context "when an own goal scorer is not playing in the match" do
      it "is invalid" do
        match = create(:match)
        other_team = create(:team, team_setup: match.home_team.team_setup, match:, team_type: Team::TEAM_TYPE_MATCH, playing: true)
        scorer_team_player = create(:team_player, team: other_team, player: create(:player))

        goal = build(:match_goal, match:, scoring_team: match.home_team, scorer_team_player:, own_goal: true)

        expect(goal).not_to be_valid
        expect(goal.errors[:scorer_team_player]).to include("must belong to the opponent for an own goal")
      end
    end

    context "when an own goal has an assistant" do
      it "is invalid" do
        match = create(:match)
        scorer_team_player = create(:team_player, team: match.away_team, player: create(:player))
        assistant_team_player = create(:team_player, team: match.home_team, player: create(:player))

        goal = build(
          :match_goal,
          match:,
          scoring_team: match.home_team,
          scorer_team_player:,
          assistant_team_player:,
          own_goal: true
        )

        expect(goal).not_to be_valid
        expect(goal.errors[:assistant_team_player]).to include("cannot be present for an own goal")
      end
    end
  end

  describe ".active" do
    it "returns only goals that were not undone" do
      match = create(:match)
      scorer = create(:player)
      scorer_team_player = create(:team_player, team: match.home_team, player: scorer)
      active_goal = create(:match_goal, match: match, scoring_team: match.home_team, scorer_team_player: scorer_team_player, scored_at: Time.zone.now)
      create(:match_goal, match: match, scoring_team: match.home_team, scorer_team_player: scorer_team_player, scored_at: 1.minute.from_now, undone_at: Time.zone.now)

      result = described_class.active

      expect(result).to contain_exactly(active_goal)
    end
  end
end
