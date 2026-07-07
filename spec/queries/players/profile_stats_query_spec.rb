require "rails_helper"

RSpec.describe Players::ProfileStatsQuery do
  describe ".call" do
    it "returns season-scoped profile stats, charts, awards, pagination, and player-filtered synergy links" do
      player = create(:player, name: "Adam Nowak", approval_status: "approved", active: true, elo: 1000)
      partner = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
      voter = create(:player, name: "Voter Demo", approval_status: "approved", active: true)
      opponent = create(:player, name: "Opponent Demo", approval_status: "approved", active: true)
      season = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1))
      older_season = create(:season, name: "Spring 2026", starts_on: Date.new(2026, 3, 1))
      create(:player_season_stat, player:, season:, elo: 1040)
      create(:player_season_stat, player: partner, season:, elo: 1030)

      finished_match = create_finished_match(
        season:,
        played_on: Date.new(2026, 7, 1),
        home_players: [ player, partner ],
        away_players: [ opponent ],
        score: [ 2, 1 ]
      )
      player_team_player = finished_match.home_team.team_players.find_by!(player:)
      partner_team_player = finished_match.home_team.team_players.find_by!(player: partner)
      opponent_team_player = finished_match.away_team.team_players.find_by!(player: opponent)
      create(
        :match_goal,
        match: finished_match,
        scoring_team: finished_match.home_team,
        scorer_team_player: player_team_player,
        assistant_team_player: partner_team_player
      )
      create(
        :match_goal,
        match: finished_match,
        scoring_team: finished_match.home_team,
        scorer_team_player: player_team_player,
        undone_at: Time.current
      )
      create(
        :match_goal,
        match: finished_match,
        scoring_team: finished_match.away_team,
        scorer_team_player: player_team_player,
        own_goal: true
      )
      create(
        :match_goal,
        match: finished_match,
        scoring_team: finished_match.home_team,
        scorer_team_player: opponent_team_player,
        own_goal: true
      )
      create(
        :player_rating_change,
        player:,
        season:,
        match_day: finished_match.match_day,
        match: finished_match,
        old_elo_score: 1020,
        elo_delta: 20,
        new_elo_score: 1040
      )
      create(
        :player_rating_change,
        player:,
        season:,
        match_day: finished_match.match_day,
        match: finished_match,
        old_elo_score: 1040,
        elo_delta: -8,
        new_elo_score: 1032,
        created_at: 1.minute.from_now
      )
      create_award_vote(match_day: finished_match.match_day, voter:, mvp_player: player, def_player: partner)

      create_finished_match(
        season: older_season,
        played_on: Date.new(2026, 5, 1),
        home_players: [ player ],
        away_players: [ opponent ],
        score: [ 0, 1 ]
      )

      result = described_class.call(player:, season:, tab: "matches", page: 1, per_page: 1)

      expect(result.season).to eq(season)
      expect(result.available_seasons).to include(season, older_season)
      expect(result.active_tab).to eq("matches")
      expect(result.summary).to include(
        current_elo: 1040,
        matches: 1,
        goals: 1,
        assists: 0,
        own_goals: 1,
        goals_assists: 1,
        mvp: 1,
        def: 0,
        wins: 1,
        draws: 0,
        losses: 0,
        win_rate: 100,
        draw_rate: 0,
        loss_rate: 0,
        best_win_streak: 1,
        season_rank: 1
      )
      expect(result.record).to include(wins: 1, draws: 0, losses: 0, total: 1, win_rate: 100, draw_rate: 0, loss_rate: 0)
      expect(result.matches.first).to have_attributes(
        match: finished_match,
        score: "2:1",
        result: Team::RESULT_WIN,
        goals: 1,
        assists: 0,
        own_goals: 1,
        elo_before: 1040,
        elo_delta: -8,
        elo_after: 1032,
        award_types: [ "MVP" ]
      )
      expect(result.paginated_matches.items).to eq([ result.matches.first ])
      expect(result.paginated_matches.total_pages).to eq(1)
      expect(result.awards.first).to have_attributes(match_day: finished_match.match_day, award_type: "MVP", votes_count: 1)
      expect(result.chart_data.fetch(:elo).fetch(:datasets).first.fetch(:data)).to eq([ 1040, 1032 ])
      expect(result.chart_data.fetch(:elo).fetch(:datasets).first.fetch(:segmentByDelta)).to be(true)
      expect(result.chart_data.fetch(:elo).fetch(:datasets).first.fetch(:tension)).to eq(0)
      expect(result.chart_data.fetch(:elo).fetch(:datasets).first.fetch(:pointBackgroundColor)).to eq([ "#22C55E", "#EF4444" ])
      expect(result.chart_data.fetch(:elo).fetch(:points_meta).first.fetch(:result_label)).to eq("Wygrana")
      expect(result.chart_data.fetch(:record).fetch(:datasets).first.fetch(:backgroundColor)).to eq([ "#22C55E", "#94A3B8", "#EF4444" ])
      expect(result.chart_data.fetch(:cumulative_goals).fetch(:datasets).first.fetch(:data)).to eq([ 1 ])
      expect(result.synergy.fetch(:best_partner).players).to contain_exactly(player, partner)
      expect(result.synergy.fetch(:graph_path)).to include("player_id=#{player.id}")
      expect(result.synergy.fetch(:graph_path)).to include("player_filter=Adam+Nowak")
      expect(result.synergy.fetch(:graph_path)).to include("minimum_shared_matches=1")
    end

    it "calculates record percentages and best win streak from chronological match results" do
      player = create(:player, approval_status: "approved", active: true)
      opponent = create(:player, approval_status: "approved", active: true)
      season = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1))
      create_finished_match(season:, played_on: Date.new(2026, 7, 1), home_players: [ player ], away_players: [ opponent ], score: [ 1, 0 ])
      create_finished_match(season:, played_on: Date.new(2026, 7, 8), home_players: [ player ], away_players: [ opponent ], score: [ 2, 0 ])
      create_finished_match(season:, played_on: Date.new(2026, 7, 15), home_players: [ player ], away_players: [ opponent ], score: [ 1, 1 ])
      create_finished_match(season:, played_on: Date.new(2026, 7, 22), home_players: [ player ], away_players: [ opponent ], score: [ 0, 1 ])

      result = described_class.call(player:, season:)

      expect(result.record).to include(
        wins: 2,
        draws: 1,
        losses: 1,
        total: 4,
        win_rate: 50,
        draw_rate: 25,
        loss_rate: 25
      )
      expect(result.summary.fetch(:best_win_streak)).to eq(2)
    end

    it "normalizes unsupported tab and returns an empty result for players without finished matches" do
      player = create(:player, approval_status: "approved", active: true)

      result = described_class.call(player:, tab: "missing", page: 0, per_page: 0)

      expect(result.active_tab).to eq("overview")
      expect(result.summary).to include(matches: 0, goals: 0, assists: 0, goals_assists: 0)
      expect(result.matches).to eq([])
      expect(result.paginated_matches.items).to eq([])
      expect(result.chart_data.fetch(:record).fetch(:values)).to eq([ 0, 0, 0 ])
    end
  end

  def create_finished_match(season:, played_on:, home_players:, away_players:, score:)
    match_day = create(:match_day, season:, played_on:, status: "finished")
    team_setup = create(:team_setup, match_day:)
    home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
    away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
    home_players.each { |player| create(:team_player, team: home_team, player:) }
    away_players.each { |player| create(:team_player, team: away_team, player:) }
    create(
      :match,
      match_day:,
      home_team:,
      away_team:,
      home_score: score.first,
      away_score: score.second,
      finished_at: Time.zone.local(2026, 7, 1, 20, 0, 0)
    )
  end

  def create_award_vote(match_day:, voter:, mvp_player:, def_player:)
    match_day_player = create(:match_day_player, match_day:, player: voter)
    token = create(:match_day_vote_token, match_day_player:)

    MatchDayVote.create!(
      match_day_vote_token: token,
      mvp_player:,
      def_player:
    )
  end
end
