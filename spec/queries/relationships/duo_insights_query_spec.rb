require "rails_helper"

RSpec.describe Relationships::DuoInsightsQuery do
  describe ".call" do
    context "when duos have shared finished matches" do
      it "returns top duo summaries with record, win rate, and offensive totals" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)

        5.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 6, index + 1), status: "finished")
          [ adam, bartek, cezary ].each { |player| create(:match_day_player, match_day:, player:) }
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: home_team, player: adam)
          bartek_team_player = create(:team_player, team: home_team, player: bartek)
          create(:team_player, team: away_team, player: cezary)
          match = create(
            :match,
            match_day:,
            home_team:,
            away_team:,
            home_score: 2,
            away_score: 1,
            finished_at: index.days.ago
          )
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: bartek_team_player)
        end

        result = described_class.call(season:)

        expect(result.best_overall_duo.player_a).to eq(adam)
        expect(result.most_played_duo.player_b).to eq(bartek)
        expect(result.best_win_rate_duo.win_rate).to eq(100)
        expect(result.best_offensive_duo.direct_offense_total).to eq(10)
        expect(result.best_offensive_duo.mutual_assists).to eq(5)
        expect(result.best_offensive_duo.shared_matches_count).to eq(5)
        expect(result.summaries.first.wins).to eq(5)
        expect(result.summaries.first.assists).to eq(5)
      end

      it "selects the offensive duo by direct assists between duo members" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)
        damian = create(:player, name: "Damian Demo", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 6, index + 1), status: "finished")
          [ adam, bartek, cezary, damian ].each { |player| create(:match_day_player, match_day:, player:) }
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: home_team, player: adam)
          bartek_team_player = create(:team_player, team: home_team, player: bartek)
          cezary_team_player = create(:team_player, team: away_team, player: cezary)
          damian_team_player = create(:team_player, team: away_team, player: damian)
          match = create(
            :match,
            match_day:,
            home_team:,
            away_team:,
            home_score: 3,
            away_score: 2,
            status: Match::STATUS_FINISHED,
            finished_at: index.days.ago
          )
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: bartek_team_player)
          create(:match_goal, match:, scoring_team: away_team, scorer_team_player: cezary_team_player)
          create(:match_goal, match:, scoring_team: away_team, scorer_team_player: cezary_team_player)
          create(:match_goal, match:, scoring_team: away_team, scorer_team_player: damian_team_player)
        end

        result = described_class.call(season:)

        expect(result.best_offensive_duo.player_a).to eq(adam)
        expect(result.best_offensive_duo.player_b).to eq(bartek)
        expect(result.best_offensive_duo.mutual_assists).to eq(3)
      end
    end

    context "when offensive stats are missing" do
      it "does not select an offensive duo" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 7, index + 1), status: "finished")
          [ adam, bartek ].each { |player| create(:match_day_player, match_day:, player:) }
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          create(:team_player, team: home_team, player: adam)
          create(:team_player, team: home_team, player: bartek)
          create(:match, match_day:, home_team:, away_team:, home_score: 0, away_score: 0, finished_at: index.days.ago)
        end

        result = described_class.call(season:)

        expect(result.best_offensive_duo).to be_nil
      end
    end

    context "when only shared match day data is available" do
      it "falls back to shared match days" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 8, index + 1), status: "finished")
          [ adam, bartek ].each { |player| create(:match_day_player, match_day:, player:) }
        end

        result = described_class.call(season:)

        expect(result.best_overall_duo.shared_count).to eq(3)
        expect(result.best_win_rate_duo.win_rate).to be_nil
        expect(result.summaries.first.match_level?).to be(false)
      end
    end

    context "when a duo plays away and loses" do
      it "counts the shared away team and loss record" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)

        match_day = create(:match_day, season:, played_on: Date.new(2026, 9, 1), status: "finished")
        [ adam, bartek, cezary ].each { |player| create(:match_day_player, match_day:, player:) }
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: cezary)
        create(:team_player, team: away_team, player: adam)
        create(:team_player, team: away_team, player: bartek)
        create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 0, finished_at: 1.day.ago)

        result = described_class.call(season:)

        expect(result.summaries.first.shared_matches_count).to eq(1)
        expect(result.summaries.first.losses).to eq(1)
      end
    end

    context "when match-level data exists for some duos" do
      it "does not use shared-day fallback for win-rate ranking" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 10, index + 1), status: "finished")
          [ adam, bartek, cezary ].each { |player| create(:match_day_player, match_day:, player:) }
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          create(:team_player, team: home_team, player: adam)
          create(:team_player, team: home_team, player: bartek)
          create(:team_player, team: away_team, player: cezary)
          create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: index.days.ago)
        end

        result = described_class.call(season:)

        expect(result.best_win_rate_duo).to be_nil
      end
    end

    context "when internal fallbacks are evaluated" do
      it "supports offensive match-day fallback eligibility and ignores non-shared matches" do
        query = described_class.new(season: nil, players: [])
        summary = Relationships::DuoInsightsQuery::Summary.new(
          shared_match_days_count: 2,
          shared_matches_count: 0,
          goals: 1,
          assists: 1,
          mutual_assists: 1
        )
        home_team = build_stubbed(:team)
        away_team = build_stubbed(:team)
        match = build_stubbed(:match, home_team:, away_team:)

        expect(query.send(:eligible_for_offensive_duo?, summary, match_level_available: false)).to be(true)
        expect(query.send(:eligible_for_offensive_duo?, summary, match_level_available: true)).to be(false)
        expect(query.send(:shared_match_for, match:, shared_team_ids: [])).to be_nil
      end
    end
  end
end
