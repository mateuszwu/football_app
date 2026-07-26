require "rails_helper"

RSpec.describe Synergy::CombinationRankingQuery do
  describe Synergy::CombinationRankingQuery::Result do
    it "returns no win rate without shared matches" do
      result = described_class.new(shared_matches_count: 0, wins: 0)

      expect(result.win_rate).to be_nil
    end

    it "calculates the overall score from wins, draws, goals, and assists" do
      result = described_class.new(wins: 6, draws: 1, goals: 2, assists: 3)

      expect(result.overall_score).to eq(24)
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
          cezary_team_player = create(:team_player, team: home_team, player: cezary)
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
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: cezary_team_player, assistant_team_player: adam_team_player)
        end

        result = described_class.call(
          season:,
          combination_size: 2,
          direction: "best",
          limit: 20,
          minimum_shared_matches: 3,
          player_filter: nil
        )

        adam_and_bartek = result.find { |entry| entry.players.sort_by(&:id) == [ adam, bartek ].sort_by(&:id) }
        adam_and_cezary = result.find { |entry| entry.players.sort_by(&:id) == [ adam, cezary ].sort_by(&:id) }

        expect(result.size).to eq(3)
        expect(adam_and_bartek.shared_matches_count).to eq(3)
        expect(adam_and_bartek.wins).to eq(3)
        expect(adam_and_bartek.win_rate).to eq(100)
        expect(adam_and_bartek.goals).to eq(3)
        expect(adam_and_bartek.assists).to eq(6)
        expect(adam_and_bartek.goals_assists).to eq(9)
        expect(adam_and_bartek.mutual_assists).to eq(3)
        expect(adam_and_cezary.goals).to eq(6)
        expect(adam_and_cezary.assists).to eq(3)
        expect(adam_and_cezary.mutual_assists).to eq(3)
        expect(result.map(&:rank)).to eq([ 1, 1, 3 ])
      end

      it "uses mutual assists as a tie breaker before player names" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", nickname: "adam", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", nickname: "bartek", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", nickname: "cezary", approval_status: "approved", active: true)
        dawid = create(:player, name: "Dawid Demo", nickname: "dawid", approval_status: "approved", active: true)
        opponent = create(:player, name: "Opponent Demo", nickname: "opponent", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 6, index + 10), status: "finished")
          team_setup = create(:team_setup, match_day:)
          first_home = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          first_away = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: first_home, player: adam)
          bartek_team_player = create(:team_player, team: first_home, player: bartek)
          create(:team_player, team: first_away, player: opponent)
          first_match = create(:match, match_day:, home_team: first_home, away_team: first_away, home_score: 1, away_score: 0, finished_at: index.days.ago)
          create(:match_goal, match: first_match, scoring_team: first_home, scorer_team_player: adam_team_player, assistant_team_player: bartek_team_player)

          second_home = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          second_away = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          cezary_team_player = create(:team_player, team: second_home, player: cezary)
          dawid_team_player = create(:team_player, team: second_home, player: dawid)
          create(:team_player, team: second_away, player: opponent)
          second_match = create(:match, match_day:, home_team: second_home, away_team: second_away, home_score: 2, away_score: 0, finished_at: index.days.ago + 30.minutes)
          create(:match_goal, match: second_match, scoring_team: second_home, scorer_team_player: cezary_team_player)
          create(:match_goal, match: second_match, scoring_team: second_home, scorer_team_player: dawid_team_player)
        end

        result = described_class.call(
          season:,
          combination_size: 2,
          direction: "best",
          limit: 20,
          minimum_shared_matches: 3,
          player_filter: nil
        )

        expect(result.first.players).to contain_exactly(adam, bartek)
        expect(result.first.goals_assists).to eq(result.second.goals_assists)
        expect(result.first.mutual_assists).to eq(3)
        expect(result.second.players).to contain_exactly(cezary, dawid)
        expect(result.second.mutual_assists).to eq(0)
        expect(result.map(&:rank).first(2)).to eq([ 1, 2 ])
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

    context "when combinations have different sample sizes" do
      it "prefers the higher overall score over a higher small-sample win rate" do
        season = create(:season)
        short_sample_one = create(:player, name: "Short One", approval_status: "approved", active: true)
        short_sample_two = create(:player, name: "Short Two", approval_status: "approved", active: true)
        long_sample_one = create(:player, name: "Long One", approval_status: "approved", active: true)
        long_sample_two = create(:player, name: "Long Two", approval_status: "approved", active: true)
        opponent = create(:player, name: "Opponent", approval_status: "approved", active: true)

        create_finished_match = lambda do |match_day:, home_players:, home_score:, away_score:|
          (home_players + [ opponent ]).each do |player|
            create(:match_day_player, match_day:, player:)
          end

          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          home_players.each { |player| create(:team_player, team: home_team, player:) }
          create(:team_player, team: away_team, player: opponent)

          create(
            :match,
            match_day:,
            home_team:,
            away_team:,
            home_score:,
            away_score:,
            status: Match::STATUS_FINISHED,
            finished_at: Time.current
          )
        end

        10.times do |index|
          won = index < 6
          match_day = create(:match_day, season:, played_on: Date.new(2026, 11, 1) + index.days, status: "finished")
          create_finished_match.call(
            match_day:,
            home_players: [ short_sample_one, short_sample_two ],
            home_score: won ? 1 : 0,
            away_score: won ? 0 : 1
          )
        end

        50.times do |index|
          won = index < 29
          match_day = create(:match_day, season:, played_on: Date.new(2027, 1, 1) + index.days, status: "finished")
          create_finished_match.call(
            match_day:,
            home_players: [ long_sample_one, long_sample_two ],
            home_score: won ? 1 : 0,
            away_score: won ? 0 : 1
          )
        end

        result = described_class.call(
          season:,
          combination_size: 2,
          direction: "best",
          limit: 20,
          minimum_shared_matches: 1,
          player_filter: nil
        )

        expect(result.first.players).to contain_exactly(long_sample_one, long_sample_two)
        expect(result.first.shared_matches_count).to eq(50)
        expect(result.first.win_rate).to eq(58)
        expect(result.first.overall_score).to eq(87)
        expect(result.second.players).to contain_exactly(short_sample_one, short_sample_two)
        expect(result.second.shared_matches_count).to eq(10)
        expect(result.second.win_rate).to eq(60)
        expect(result.second.overall_score).to eq(18)
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

    it "aggregates records and offense for active trio rankings" do
      season = create(:season)
      adam = create(:player, name: "Adam Trio", approval_status: "approved", active: true)
      bartek = create(:player, name: "Bartek Trio", approval_status: "approved", active: true)
      cezary = create(:player, name: "Cezary Trio", approval_status: "approved", active: true)
      opponent = create(:player, name: "Opponent Trio", approval_status: "approved", active: true)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)

      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      adam_team_player = create(:team_player, team: home_team, player: adam)
      bartek_team_player = create(:team_player, team: home_team, player: bartek)
      cezary_team_player = create(:team_player, team: home_team, player: cezary)
      create(:team_player, team: away_team, player: opponent)
      home_win = create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 1, finished_at: 3.hours.ago)
      create(:match_goal, match: home_win, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: bartek_team_player)
      create(:match_goal, match: home_win, scoring_team: home_team, scorer_team_player: cezary_team_player)

      draw_home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      draw_away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: draw_home_team, player: opponent)
      draw_adam = create(:team_player, team: draw_away_team, player: adam)
      create(:team_player, team: draw_away_team, player: bartek)
      draw_cezary = create(:team_player, team: draw_away_team, player: cezary)
      draw = create(:match, match_day:, home_team: draw_home_team, away_team: draw_away_team, home_score: 1, away_score: 1, finished_at: 2.hours.ago)
      create(:match_goal, match: draw, scoring_team: draw_away_team, scorer_team_player: draw_adam, assistant_team_player: draw_cezary)

      loss_home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      loss_away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: loss_home_team, player: opponent)
      create(:team_player, team: loss_away_team, player: adam)
      create(:team_player, team: loss_away_team, player: bartek)
      create(:team_player, team: loss_away_team, player: cezary)
      create(:match, match_day:, home_team: loss_home_team, away_team: loss_away_team, home_score: 2, away_score: 0, finished_at: 1.hour.ago)

      result = described_class.call(
        season:,
        combination_size: 3,
        direction: "best",
        limit: 20,
        minimum_shared_matches: 1
      )

      expect(result.one?).to be(true)
      expect(result.first.players).to contain_exactly(adam, bartek, cezary)
      expect(result.first).to have_attributes(
        shared_matches_count: 3,
        wins: 1,
        draws: 1,
        losses: 1,
        goals: 3,
        assists: 2,
        mutual_assists: 2,
        goal_difference: -1
      )
    end
  end
end
