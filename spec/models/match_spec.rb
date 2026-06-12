require "rails_helper"

RSpec.describe Match do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a match" do
        match = build(:match)

        expect(match).to be_valid
      end
    end

    context "when the match day is missing" do
      it "is invalid" do
        match = build(:match, match_day: nil)

        expect(match).not_to be_valid
        expect(match.errors[:match_day]).to include("must exist")
      end
    end

    context "when the home team is missing" do
      it "is invalid" do
        match = build(:match, home_team: nil)

        expect(match).not_to be_valid
        expect(match.errors[:home_team]).to include("must exist")
      end
    end

    context "when the away team is missing" do
      it "is invalid" do
        match = build(:match, away_team: nil)

        expect(match).not_to be_valid
        expect(match.errors[:away_team]).to include("must exist")
      end
    end

    context "when the score is negative" do
      it "is invalid" do
        match = build(:match, home_score: -1)

        expect(match).not_to be_valid
        expect(match.errors[:home_score]).to include("must be greater than or equal to 0")
      end
    end

    context "when the score is not an integer" do
      it "is invalid" do
        match = build(:match, away_score: 1.5)

        expect(match).not_to be_valid
        expect(match.errors[:away_score]).to include("must be an integer")
      end
    end

    context "when the same teams are already paired on the match day" do
      it "is invalid" do
        match = create(:match)
        duplicate_match = build(:match, match_day: match.match_day, home_team: match.home_team, away_team: match.away_team)

        expect(duplicate_match).not_to be_valid
        expect(duplicate_match.errors[:home_team_id]).to include("has already been taken")
      end
    end

    context "when the same team is assigned as both home and away" do
      it "is invalid" do
        home_team = create(:team)
        match = build(:match, home_team: home_team, away_team: home_team)

        expect(match).not_to be_valid
        expect(match.errors[:away_team]).to include("must be different from home team")
      end
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "belongs to a match day" do
        match = create(:match)

        expect(match.match_day).to be_present
      end

      it "belongs to a home team" do
        match = create(:match)

        expect(match.home_team).to be_present
      end

      it "belongs to an away team" do
        match = create(:match)

        expect(match.away_team).to be_present
      end

      it "has many copied teams" do
        match = create(:match)
        copied_team = create(:team, match: match)

        expect(match.teams).to include(copied_team)
      end
    end
  end

  describe "defaults" do
    context "when a match is created" do
      it "starts with a 0-0 scoreline" do
        match = create(:match)

        expect(match.home_score).to eq(0)
        expect(match.away_score).to eq(0)
      end

      it "stores lifecycle defaults" do
        match = create(:match)

        expect(match.status).to eq(Match::STATUS_PENDING)
        expect(match.timer_interval_seconds).to eq(300)
        expect(match.timer_beep_count).to eq(3)
        expect(match.ranked).to be(true)
      end
    end
  end

  describe "#finished?" do
    context "when finished_at is present" do
      it "returns true" do
        match = build(:match, finished_at: Time.current)

        match.valid?

        expect(match.finished?).to be(true)
        expect(match.status).to eq(Match::STATUS_FINISHED)
      end
    end

    context "when finished_at is missing" do
      it "returns false" do
        match = build(:match, finished_at: nil)

        match.valid?

        expect(match.finished?).to be(false)
      end
    end
  end

  describe "#in_progress?" do
    context "when the match has started and not finished" do
      it "returns true" do
        match = build(:match, started_at: Time.current, finished_at: nil)

        match.valid?

        expect(match.in_progress?).to be(true)
        expect(match.status).to eq(Match::STATUS_IN_PROGRESS)
      end
    end

    context "when the match has not started" do
      it "returns false" do
        match = build(:match, started_at: nil, finished_at: nil)

        match.valid?

        expect(match.in_progress?).to be(false)
      end
    end
  end

  describe "#not_started?" do
    context "when the match has not started" do
      it "returns true" do
        match = build(:match, started_at: nil, finished_at: nil)

        match.valid?

        expect(match.not_started?).to be(true)
        expect(match.status).to eq(Match::STATUS_PENDING)
      end
    end
  end

  describe "#recalculate_score!" do
    context "when persisted scores have drifted from recorded goals" do
      it "replaces both scores with goal counts per team" do
        match = create(:match, home_score: 4, away_score: 2)
        home_scorer = create(:player)
        away_scorer = create(:player)
        home_scorer_team_player = create(:team_player, team: match.home_team, player: home_scorer)
        away_scorer_team_player = create(:team_player, team: match.away_team, player: away_scorer)
        create(:match_goal, match: match, scoring_team: match.home_team, scorer_team_player: home_scorer_team_player, scored_at: Time.zone.now)
        create(:match_goal, match: match, scoring_team: match.away_team, scorer_team_player: away_scorer_team_player, scored_at: Time.zone.now)
        create(:match_goal, match: match, scoring_team: match.away_team, scorer_team_player: away_scorer_team_player, scored_at: 1.minute.from_now)
        create(:match_goal, match: match, scoring_team: match.home_team, scorer_team_player: home_scorer_team_player, scored_at: 2.minutes.from_now, undone_at: Time.zone.now)

        match.recalculate_score!

        expect(match.reload.home_score).to eq(1)
        expect(match.away_score).to eq(2)
      end
    end
  end

  describe "#winner" do
    context "when the home team wins" do
      it "returns the home team" do
        match = create(:match, home_score: 3, away_score: 1, started_at: Time.current)

        expect(match.winner).to eq(match.home_team)
      end
    end

    context "when the match is drawn" do
      it "returns nil" do
        match = create(:match, home_score: 2, away_score: 2, started_at: Time.current)

        expect(match.winner).to be_nil
      end
    end

    context "when the match has not started" do
      it "returns nil" do
        match = create(:match, started_at: nil)

        expect(match.winner).to be_nil
      end
    end
  end

  describe "#loser" do
    context "when the away team wins" do
      it "returns the home team" do
        match = create(:match, home_score: 0, away_score: 1, started_at: Time.current)

        expect(match.loser).to eq(match.home_team)
      end
    end

    context "when the match is drawn" do
      it "returns nil" do
        match = create(:match, home_score: 1, away_score: 1, started_at: Time.current)

        expect(match.loser).to be_nil
      end
    end
  end
end
