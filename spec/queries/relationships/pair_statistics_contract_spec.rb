require "rails_helper"

RSpec.describe "Pair statistics query contract" do
  describe "finished-match aggregation" do
    it "keeps duo, ranking, and graph metrics aligned across seasons and match statuses" do
      season = create(:season, name: "Contract Season")
      other_season = create(:season, name: "Other Contract Season")
      adam = create(:player, name: "Adam Contract", nickname: "adam-contract", approval_status: "approved", active: true)
      bartek = create(:player, name: "Bartek Contract", nickname: "bartek-contract", approval_status: "approved", active: true)
      opponent = create(:player, name: "Opponent Contract", nickname: "opponent-contract", approval_status: "approved", active: true)

      first_match_day = create(:match_day, season:, played_on: Date.new(2026, 1, 10), status: "finished")
      [ adam, bartek, opponent ].each { |player| create(:match_day_player, match_day: first_match_day, player:) }
      first_setup = create(:team_setup, match_day: first_match_day)
      first_home = create(:team, team_setup: first_setup, team_type: Team::TEAM_TYPE_MATCH)
      first_away = create(:team, team_setup: first_setup, team_type: Team::TEAM_TYPE_MATCH)
      first_adam = create(:team_player, team: first_home, player: adam)
      first_bartek = create(:team_player, team: first_home, player: bartek)
      create(:team_player, team: first_away, player: opponent)
      first_match = create(
        :match,
        match_day: first_match_day,
        home_team: first_home,
        away_team: first_away,
        home_score: 2,
        away_score: 1,
        started_at: Time.zone.parse("2026-01-10 18:00:00"),
        finished_at: Time.zone.parse("2026-01-10 19:00:00")
      )
      create(
        :match_goal,
        match: first_match,
        scoring_team: first_home,
        scorer_team_player: first_adam,
        assistant_team_player: first_bartek,
        scored_at: Time.zone.parse("2026-01-10 18:10:00")
      )
      create(
        :match_goal,
        match: first_match,
        scoring_team: first_home,
        scorer_team_player: first_bartek,
        assistant_team_player: first_adam,
        scored_at: Time.zone.parse("2026-01-10 18:20:00")
      )
      create(
        :match_goal,
        match: first_match,
        scoring_team: first_home,
        scorer_team_player: first_adam,
        assistant_team_player: first_bartek,
        scored_at: Time.zone.parse("2026-01-10 18:30:00"),
        undone_at: Time.zone.parse("2026-01-10 18:31:00")
      )

      second_match_day = create(:match_day, season:, played_on: Date.new(2026, 1, 17), status: "finished")
      [ adam, bartek, opponent ].each { |player| create(:match_day_player, match_day: second_match_day, player:) }
      second_setup = create(:team_setup, match_day: second_match_day)
      second_home = create(:team, team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH)
      second_away = create(:team, team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: second_home, player: opponent)
      second_adam = create(:team_player, team: second_away, player: adam)
      second_bartek = create(:team_player, team: second_away, player: bartek)
      second_match = create(
        :match,
        match_day: second_match_day,
        home_team: second_home,
        away_team: second_away,
        home_score: 1,
        away_score: 1,
        started_at: Time.zone.parse("2026-01-17 18:00:00"),
        finished_at: Time.zone.parse("2026-01-17 19:00:00")
      )
      create(
        :match_goal,
        match: second_match,
        scoring_team: second_away,
        scorer_team_player: second_bartek,
        assistant_team_player: second_adam,
        scored_at: Time.zone.parse("2026-01-17 18:10:00")
      )

      unfinished_match_day = create(:match_day, season:, played_on: Date.new(2026, 1, 24), status: "in_progress")
      [ adam, bartek, opponent ].each { |player| create(:match_day_player, match_day: unfinished_match_day, player:) }
      unfinished_setup = create(:team_setup, match_day: unfinished_match_day)
      unfinished_home = create(:team, team_setup: unfinished_setup, team_type: Team::TEAM_TYPE_MATCH)
      unfinished_away = create(:team, team_setup: unfinished_setup, team_type: Team::TEAM_TYPE_MATCH)
      unfinished_adam = create(:team_player, team: unfinished_home, player: adam)
      unfinished_bartek = create(:team_player, team: unfinished_home, player: bartek)
      create(:team_player, team: unfinished_away, player: opponent)
      unfinished_match = create(
        :match,
        match_day: unfinished_match_day,
        home_team: unfinished_home,
        away_team: unfinished_away,
        home_score: 1,
        away_score: 0,
        started_at: Time.zone.parse("2026-01-24 18:00:00")
      )
      create(
        :match_goal,
        match: unfinished_match,
        scoring_team: unfinished_home,
        scorer_team_player: unfinished_adam,
        assistant_team_player: unfinished_bartek,
        scored_at: Time.zone.parse("2026-01-24 18:10:00")
      )

      other_match_day = create(:match_day, season: other_season, played_on: Date.new(2026, 1, 10), status: "finished")
      [ adam, bartek, opponent ].each { |player| create(:match_day_player, match_day: other_match_day, player:) }
      other_setup = create(:team_setup, match_day: other_match_day)
      other_home = create(:team, team_setup: other_setup, team_type: Team::TEAM_TYPE_MATCH)
      other_away = create(:team, team_setup: other_setup, team_type: Team::TEAM_TYPE_MATCH)
      other_adam = create(:team_player, team: other_home, player: adam)
      other_bartek = create(:team_player, team: other_home, player: bartek)
      create(:team_player, team: other_away, player: opponent)
      other_match = create(
        :match,
        match_day: other_match_day,
        home_team: other_home,
        away_team: other_away,
        home_score: 1,
        away_score: 0,
        started_at: Time.zone.parse("2026-01-10 20:00:00"),
        finished_at: Time.zone.parse("2026-01-10 21:00:00")
      )
      create(
        :match_goal,
        match: other_match,
        scoring_team: other_home,
        scorer_team_player: other_adam,
        assistant_team_player: other_bartek,
        scored_at: Time.zone.parse("2026-01-10 20:10:00")
      )

      duo_insights = Relationships::DuoInsightsQuery.call(season:)
      ranking = Synergy::CombinationRankingQuery.call(
        season:,
        combination_size: 2,
        direction: "best",
        limit: 20,
        minimum_shared_matches: 1
      )
      graph = Synergy::GraphDataQuery.call(
        season:,
        minimum_shared_matches: 1,
        limit: 100,
        metric: "shared_matches"
      )

      duo = duo_insights.summaries.find { |entry| [ entry.player_a.id, entry.player_b.id ].sort == [ adam.id, bartek.id ].sort }
      combination = ranking.find { |entry| entry.players.map(&:id).sort == [ adam.id, bartek.id ].sort }
      graph_edge = graph.fetch(:elements).find do |element|
        data = element.fetch(:data)
        [ data[:source], data[:target] ].compact.sort == [ "player-#{adam.id}", "player-#{bartek.id}" ].sort
      end.fetch(:data)

      expect(duo).to have_attributes(
        shared_match_days_count: 3,
        shared_matches_count: 2,
        wins: 1,
        draws: 1,
        losses: 0,
        goals: 3,
        assists: 3,
        mutual_assists: 3
      )
      expect(combination).to have_attributes(
        shared_matches_count: duo.shared_matches_count,
        wins: duo.wins,
        draws: duo.draws,
        losses: duo.losses,
        goals: duo.goals,
        assists: duo.assists,
        mutual_assists: duo.mutual_assists
      )
      expect(graph_edge).to include(
        shared_matches: duo.shared_matches_count,
        wins: duo.wins,
        draws: duo.draws,
        losses: duo.losses,
        goals: duo.goals,
        assists: duo.assists
      )
    end

    it "counts multiple finished matches separately from one shared match day" do
      season = create(:season)
      adam = create(:player, name: "Adam Multi", nickname: "adam-multi", approval_status: "approved", active: true)
      bartek = create(:player, name: "Bartek Multi", nickname: "bartek-multi", approval_status: "approved", active: true)
      opponent = create(:player, name: "Opponent Multi", nickname: "opponent-multi", approval_status: "approved", active: true)
      match_day = create(:match_day, season:, status: "finished")
      [ adam, bartek, opponent ].each { |player| create(:match_day_player, match_day:, player:) }
      team_setup = create(:team_setup, match_day:)

      2.times do |index|
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: adam)
        create(:team_player, team: home_team, player: bartek)
        create(:team_player, team: away_team, player: opponent)
        create(
          :match,
          match_day:,
          home_team:,
          away_team:,
          home_score: 1,
          away_score: 0,
          started_at: Time.zone.parse("2026-06-05 18:00:00") + index.hours,
          finished_at: Time.zone.parse("2026-06-05 18:30:00") + index.hours
        )
      end

      duo_insights = Relationships::DuoInsightsQuery.call(season:)
      ranking = Synergy::CombinationRankingQuery.call(
        season:,
        combination_size: 2,
        direction: "best",
        limit: 20,
        minimum_shared_matches: 1
      )

      duo = duo_insights.summaries.find { |entry| [ entry.player_a.id, entry.player_b.id ].sort == [ adam.id, bartek.id ].sort }
      combination = ranking.find { |entry| entry.players.map(&:id).sort == [ adam.id, bartek.id ].sort }

      expect(duo.shared_match_days_count).to eq(1)
      expect(duo.shared_matches_count).to eq(2)
      expect(combination.shared_matches_count).to eq(2)
    end
  end

  describe "public visibility and active goals" do
    it "excludes hidden players, undone goals, and own goals from pair offense" do
      season = create(:season)
      adam = create(:player, name: "Adam Visible", nickname: "adam-visible", approval_status: "approved", active: true)
      bartek = create(:player, name: "Bartek Visible", nickname: "bartek-visible", approval_status: "approved", active: true)
      pending = create(:player, name: "Pending Hidden", nickname: "pending-hidden", approval_status: "pending", active: true)
      inactive = create(:player, name: "Inactive Hidden", nickname: "inactive-hidden", approval_status: "approved", active: false)
      opponent = create(:player, name: "Opponent Visible", nickname: "opponent-visible", approval_status: "approved", active: true)
      match_day = create(:match_day, season:, status: "finished")
      [ adam, bartek, pending, inactive, opponent ].each { |player| create(:match_day_player, match_day:, player:) }
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      adam_team_player = create(:team_player, team: home_team, player: adam)
      bartek_team_player = create(:team_player, team: home_team, player: bartek)
      create(:team_player, team: home_team, player: pending)
      create(:team_player, team: home_team, player: inactive)
      create(:team_player, team: away_team, player: opponent)
      match = create(
        :match,
        match_day:,
        home_team:,
        away_team:,
        home_score: 1,
        away_score: 1,
        started_at: Time.zone.parse("2026-06-05 18:00:00"),
        finished_at: Time.zone.parse("2026-06-05 19:00:00")
      )
      create(
        :match_goal,
        match:,
        scoring_team: home_team,
        scorer_team_player: adam_team_player,
        scored_at: Time.zone.parse("2026-06-05 18:10:00")
      )
      create(
        :match_goal,
        match:,
        scoring_team: home_team,
        scorer_team_player: bartek_team_player,
        scored_at: Time.zone.parse("2026-06-05 18:20:00"),
        undone_at: Time.zone.parse("2026-06-05 18:21:00")
      )
      create(
        :match_goal,
        match:,
        scoring_team: away_team,
        scorer_team_player: adam_team_player,
        own_goal: true,
        scored_at: Time.zone.parse("2026-06-05 18:30:00")
      )

      ranking = Synergy::CombinationRankingQuery.call(
        season:,
        combination_size: 2,
        direction: "best",
        limit: 20,
        minimum_shared_matches: 1
      )
      graph = Synergy::GraphDataQuery.call(
        season:,
        minimum_shared_matches: 1,
        limit: 100,
        metric: "goals_assists"
      )

      visible_pair = ranking.find { |entry| entry.players.map(&:id).sort == [ adam.id, bartek.id ].sort }
      graph_edge = graph.fetch(:elements).find do |element|
        data = element.fetch(:data)
        [ data[:source], data[:target] ].compact.sort == [ "player-#{adam.id}", "player-#{bartek.id}" ].sort
      end.fetch(:data)

      expect(visible_pair).to have_attributes(goals: 1, assists: 0)
      expect(ranking.flat_map(&:players)).not_to include(pending, inactive)
      expect(graph_edge).to include(goals: 1, assists: 0)
      expect(graph.fetch(:elements).to_json).not_to include(pending.name, inactive.name)
    end
  end
end
