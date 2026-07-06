require "rails_helper"

RSpec.describe Synergy::CombinationRankingQuery do
  describe Synergy::CombinationRankingQuery::Result do
    it "returns no win rate without shared matches" do
      result = described_class.new(shared_matches_count: 0, wins: 0)

      expect(result.win_rate).to be_nil
    end
  end

  describe ".call" do
    context "when players share finished match teams" do
      it "returns limited ranked combinations with record and offensive totals" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", nickname: "adam", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", nickname: "bartek", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", nickname: "cezary", approval_status: "approved", active: true)
        damian = create(:player, name: "Damian Demo", nickname: "damian", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 6, index + 1), status: "finished")
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: home_team, player: adam)
          bartek_team_player = create(:team_player, team: home_team, player: bartek)
          create(:team_player, team: home_team, player: cezary)
          create(:team_player, team: away_team, player: damian)
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

        result = described_class.call(
          season:,
          combination_size: 3,
          direction: "best",
          limit: 20,
          minimum_shared_matches: 3,
          player_filter: nil
        )

        expect(result.size).to eq(1)
        expect(result.first.players).to contain_exactly(adam, bartek, cezary)
        expect(result.first.shared_matches_count).to eq(3)
        expect(result.first.wins).to eq(3)
        expect(result.first.win_rate).to eq(100)
        expect(result.first.goals).to eq(3)
        expect(result.first.assists).to eq(3)
        expect(result.first.goals_assists).to eq(6)
      end
    end

    context "when filters are applied" do
      it "keeps only combinations containing the searched player" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", nickname: "adam", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", nickname: "bartek", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", nickname: "cezary", approval_status: "approved", active: true)
        damian = create(:player, name: "Damian Demo", nickname: "damian", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 7, index + 1), status: "finished")
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          create(:team_player, team: home_team, player: adam)
          create(:team_player, team: home_team, player: bartek)
          create(:team_player, team: home_team, player: cezary)
          create(:team_player, team: away_team, player: damian)
          create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: index.days.ago)
        end

        result = described_class.call(
          season:,
          combination_size: 2,
          direction: "best",
          limit: 20,
          minimum_shared_matches: 1,
          player_filter: "cez"
        )

        expect(result.size).to eq(2)
        expect(result).to all(have_attributes(players: include(cezary)))
      end

      it "keeps only combinations containing the selected player id" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", nickname: "adam", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", nickname: "bartek", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", nickname: "cezary", approval_status: "approved", active: true)
        damian = create(:player, name: "Damian Demo", nickname: "damian", approval_status: "approved", active: true)

        match_day = create(:match_day, season:, played_on: Date.new(2026, 7, 10), status: "finished")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: adam)
        create(:team_player, team: home_team, player: bartek)
        create(:team_player, team: home_team, player: cezary)
        create(:team_player, team: away_team, player: damian)
        create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: Time.current)

        result = described_class.call(
          season:,
          combination_size: 2,
          direction: "best",
          limit: 20,
          minimum_shared_matches: 1,
          player_id: adam.id
        )

        expect(result.size).to eq(2)
        expect(result).to all(have_attributes(players: include(adam)))
      end
    end

    context "when worst direction is selected" do
      it "sorts lower win-rate combinations first" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)
        damian = create(:player, name: "Damian Demo", approval_status: "approved", active: true)

        winning_day = create(:match_day, season:, played_on: Date.new(2026, 8, 1), status: "finished")
        winning_setup = create(:team_setup, match_day: winning_day)
        winning_home = create(:team, team_setup: winning_setup, team_type: Team::TEAM_TYPE_MATCH)
        winning_away = create(:team, team_setup: winning_setup, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: winning_home, player: adam)
        create(:team_player, team: winning_home, player: bartek)
        create(:team_player, team: winning_away, player: damian)
        create(:match, match_day: winning_day, home_team: winning_home, away_team: winning_away, home_score: 1, away_score: 0, finished_at: 1.day.ago)

        losing_day = create(:match_day, season:, played_on: Date.new(2026, 8, 2), status: "finished")
        losing_setup = create(:team_setup, match_day: losing_day)
        losing_home = create(:team, team_setup: losing_setup, team_type: Team::TEAM_TYPE_MATCH)
        losing_away = create(:team, team_setup: losing_setup, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: losing_home, player: cezary)
        create(:team_player, team: losing_home, player: damian)
        create(:team_player, team: losing_away, player: adam)
        create(:match, match_day: losing_day, home_team: losing_home, away_team: losing_away, home_score: 0, away_score: 2, finished_at: Time.current)

        result = described_class.call(
          season:,
          combination_size: 2,
          direction: "worst",
          limit: 20,
          minimum_shared_matches: 1,
          player_filter: nil
        )

        expect(result.first.players).to contain_exactly(cezary, damian)
        expect(result.first.losses).to eq(1)
      end
    end

    context "when default options and away draws are used" do
      it "normalizes invalid options and counts away goal difference and draws" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)

        match_day = create(:match_day, season:, played_on: Date.new(2026, 9, 1), status: "finished")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: cezary)
        create(:team_player, team: away_team, player: adam)
        create(:team_player, team: away_team, player: bartek)
        create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 1, finished_at: Time.current)

        result = described_class.call(
          season:,
          combination_size: 9,
          direction: "invalid",
          limit: 999,
          minimum_shared_matches: 0,
          player_filter: ""
        )

        expect(result.first.players).to contain_exactly(adam, bartek)
        expect(result.first.draws).to eq(1)
        expect(result.first.goal_difference).to eq(0)
      end
    end
  end
end
