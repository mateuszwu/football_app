require "rails_helper"

RSpec.describe Stats::MatchTimelineQuery do
  describe ".call" do
    context "when a finished match has ordered active goals" do
      it "returns score states and contextual goal flags" do
        season = create(:season)
        match, home_team, away_team, home_players, away_players = create_match_with_players(season:)
        start_time = Time.zone.local(2026, 7, 7, 18, 0, 0)
        match.update!(started_at: start_time, finished_at: start_time + 12.minutes, home_score: 5, away_score: 4)

        create_goal(match:, scoring_team: home_team, scorer_team_player: home_players.first, scored_at: start_time + 120.seconds)
        create_goal(match:, scoring_team: away_team, scorer_team_player: away_players.first, scored_at: start_time + 150.seconds)
        create_goal(match:, scoring_team: home_team, scorer_team_player: home_players.first, scored_at: start_time + 210.seconds)
        undone_goal = create_goal(match:, scoring_team: away_team, scorer_team_player: away_players.first, scored_at: start_time + 220.seconds)
        undone_goal.update!(undone_at: Time.current)
        create_goal(match:, scoring_team: away_team, scorer_team_player: away_players.first, scored_at: start_time + 260.seconds)
        create_goal(match:, scoring_team: home_team, scorer_team_player: home_players.first, scored_at: start_time + 300.seconds)
        create_goal(match:, scoring_team: away_team, scorer_team_player: away_players.first, scored_at: start_time + 340.seconds)
        create_goal(match:, scoring_team: home_team, scorer_team_player: home_players.first, scored_at: start_time + 400.seconds)
        create_goal(match:, scoring_team: away_team, scorer_team_player: away_players.first, scored_at: start_time + 430.seconds)
        create_goal(match:, scoring_team: home_team, scorer_team_player: home_players.first, scored_at: start_time + 470.seconds)

        result = described_class.call(match:)

        expect(result.events.size).to eq(9)
        expect(result.events.first).to include(
          occurred_at_seconds: 120,
          score_before: { team_a: 0, team_b: 0 },
          score_after: { team_a: 1, team_b: 0 },
          is_first_goal: true,
          is_go_ahead_goal: true
        )
        expect(result.events.second).to include(is_equalizer: true, score_after: { team_a: 1, team_b: 1 })
        expect(result.events.last).to include(is_closing_goal: true, goal_number_for_team: 5, match_goal_number: 9)
        expect(result.summary).to include(
          completed_to_5: true,
          duration_seconds: 470,
          winner_team: home_team,
          loser_team: away_team,
          equalizers_count: 4,
          lead_changes_count: 0
        )
      end
    end

    context "when a winner comes back from a deficit" do
      it "detects biggest comeback and wasted lead" do
        season = create(:season)
        match, home_team, away_team, home_players, away_players = create_match_with_players(season:)
        start_time = Time.zone.local(2026, 7, 7, 18, 0, 0)
        match.update!(started_at: start_time, finished_at: start_time + 10.minutes, home_score: 5, away_score: 3)

        3.times { |index| create_goal(match:, scoring_team: away_team, scorer_team_player: away_players.first, scored_at: start_time + (index + 1).minutes) }
        5.times { |index| create_goal(match:, scoring_team: home_team, scorer_team_player: home_players.first, scored_at: start_time + (index + 4).minutes) }

        result = described_class.call(match:)

        expect(result.summary).to include(
          biggest_deficit_overcome_by_winner: 3,
          biggest_wasted_lead_by_loser: 3,
          lead_changes_count: 1
        )
      end
    end
  end

  def create_match_with_players(season:)
    match_day = create(:match_day, season:, status: "finished", played_on: Date.new(2026, 7, 7))
    team_setup = create(:team_setup, match_day:)
    home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Zieloni")
    away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Czarni")
    home_players = [ create(:team_player, team: home_team, player: create(:player, approval_status: "approved", active: true)) ]
    away_players = [ create(:team_player, team: away_team, player: create(:player, approval_status: "approved", active: true)) ]
    match = create(:match, match_day:, home_team:, away_team:, home_score: 0, away_score: 0)

    [ match, home_team, away_team, home_players, away_players ]
  end

  def create_goal(match:, scoring_team:, scorer_team_player:, scored_at:)
    create(
      :match_goal,
      match:,
      scoring_team:,
      scorer_team_player:,
      scored_at:
    )
  end
end
