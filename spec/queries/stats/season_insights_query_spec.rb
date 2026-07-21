require "rails_helper"

RSpec.describe Stats::SeasonInsightsQuery do
  describe ".call" do
    context "when the season has reconstructable completed matches" do
      it "returns top cards, comeback rates, score states and clutch rows" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        first_match = create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 1),
          home_player: adam,
          away_player: bartek,
          scores: [
            [ :away, 30 ],
            [ :away, 60 ],
            [ :home, 120 ],
            [ :home, 180 ],
            [ :home, 240 ],
            [ :away, 300 ],
            [ :home, 360 ],
            [ :home, 420 ]
          ],
          final_score: [ 5, 3 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 8),
          home_player: adam,
          away_player: bartek,
          scores: [
            [ :home, 90 ],
            [ :home, 120 ],
            [ :home, 180 ],
            [ :home, 240 ],
            [ :home, 300 ]
          ],
          final_score: [ 5, 0 ]
        )

        result = described_class.call(season:)

        expect(result.dig(:top_cards, :fastest_goal)).to include(value: "00:30", subject: "Bartek Demo")
        expect(result.dig(:top_cards, :shortest_match)).to include(value: "05:00")
        expect(result.dig(:tempo, :average_match_duration)).to eq(360)
        expect(result.dig(:first_goal, :matches_count)).to eq(2)
        expect(result.dig(:first_goal, :first_goal_win_rate)).to eq(50)
        first_goal_rows = result.dig(:first_goal, :player_rows).index_by { |row| row.fetch(:player).name }
        expect(first_goal_rows.fetch("Adam Demo")).to include(first_goals: 1, matches: 2, first_goal_rate: 50)
        expect(first_goal_rows.fetch("Bartek Demo")).to include(first_goals: 1, matches: 2, first_goal_rate: 50)
        expect(result.dig(:comebacks, :threshold_rows).find { |row| row.fetch(:deficit) == "0:2" }).to include(comeback_wins: 1)
        expect(result.dig(:score_states, :rows).map { |row| row.fetch(:state) }).to include("2:0", "4:0")
        expect(result.dig(:sidebar, :most_common_scenario)).to be_nil
        most_goals_match = result.dig(:records, :rows).find { |row| row.fetch(:key) == "most_goals_match" }
        expect(most_goals_match).to include(subject: "Adam Demo", value: "5 goli", match: first_match)
        biggest_domination = result.dig(:records, :rows).find { |row| row.fetch(:key) == "biggest_domination" }
        expect(biggest_domination).to include(value: "+5 / 5:0")
        expect(result.fetch(:clutch_players).find { |row| row.fetch(:player) == adam }).to include(closing_goals: 2)
        expect(result.dig(:chart_data, :match_durations, :labels)).to include("2026-07-01 · ##{first_match.id}")
      end

      it "sorts first goal players by first goals, rate, win rate, and name" do
        season = create(:season)
        high_win_player = create(:player, name: "Zed Demo", approval_status: "approved", active: true)
        low_win_player = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        alpha_first_player = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        alpha_second_player = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)
        opponent = create(:player, name: "Opponent Demo", approval_status: "approved", active: true)

        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 1),
          home_player: low_win_player,
          away_player: opponent,
          scores: [ [ :home, 30 ], [ :away, 60 ], [ :away, 90 ], [ :away, 120 ], [ :away, 150 ], [ :away, 180 ] ],
          final_score: [ 1, 5 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 2),
          home_player: low_win_player,
          away_player: opponent,
          scores: [ [ :home, 30 ], [ :away, 60 ], [ :away, 90 ], [ :away, 120 ], [ :away, 150 ], [ :away, 180 ] ],
          final_score: [ 1, 5 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 3),
          home_player: high_win_player,
          away_player: opponent,
          scores: [ [ :home, 30 ], [ :home, 60 ], [ :home, 90 ], [ :home, 120 ], [ :home, 150 ] ],
          final_score: [ 5, 0 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 4),
          home_player: high_win_player,
          away_player: opponent,
          scores: [ [ :home, 30 ], [ :away, 60 ], [ :home, 90 ], [ :home, 120 ], [ :home, 150 ], [ :home, 180 ] ],
          final_score: [ 5, 1 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 5),
          home_player: alpha_second_player,
          away_player: opponent,
          scores: [ [ :home, 30 ], [ :home, 60 ], [ :home, 90 ], [ :home, 120 ], [ :home, 150 ] ],
          final_score: [ 5, 0 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 6),
          home_player: alpha_first_player,
          away_player: opponent,
          scores: [ [ :home, 30 ], [ :home, 60 ], [ :home, 90 ], [ :home, 120 ], [ :home, 150 ] ],
          final_score: [ 5, 0 ]
        )

        result = described_class.call(season:)

        rows = result.dig(:first_goal, :player_rows)

        expect(rows.map { |row| row.fetch(:player).name }).to eq([ "Zed Demo", "Adam Demo", "Bartek Demo", "Cezary Demo" ])
        expect(rows.map { |row| row.fetch(:first_goals) }).to eq([ 2, 2, 1, 1 ])
        expect(rows.map { |row| row.fetch(:matches) }).to eq([ 2, 2, 1, 1 ])
        expect(rows.map { |row| row.fetch(:first_goal_rate) }).to eq([ 100, 100, 100, 100 ])
        expect(rows.map { |row| row.fetch(:win_rate_after_first_goal) }).to eq([ 100, 0, 100, 100 ])
      end

      it "selects biggest domination by margin, match speed, first goal speed, and latest match" do
        season = create(:season)
        home_player = create(:player, name: "Home Demo", approval_status: "approved", active: true)
        away_player = create(:player, name: "Away Demo", approval_status: "approved", active: true)

        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 1),
          home_player:,
          away_player:,
          scores: [ [ :home, 10 ], [ :home, 20 ], [ :home, 30 ], [ :home, 40 ], [ :away, 50 ], [ :home, 120 ] ],
          final_score: [ 5, 1 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 2),
          home_player:,
          away_player:,
          scores: [ [ :home, 90 ], [ :home, 120 ], [ :home, 180 ], [ :home, 240 ], [ :home, 300 ] ],
          final_score: [ 5, 0 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 3),
          home_player:,
          away_player:,
          scores: [ [ :home, 120 ], [ :home, 150 ], [ :home, 180 ], [ :home, 210 ], [ :home, 240 ] ],
          final_score: [ 5, 0 ]
        )
        create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 4),
          home_player:,
          away_player:,
          scores: [ [ :home, 60 ], [ :home, 150 ], [ :home, 180 ], [ :home, 210 ], [ :home, 240 ] ],
          final_score: [ 5, 0 ]
        )
        latest_tied_match = create_completed_match(
          season:,
          played_on: Date.new(2026, 7, 5),
          home_player:,
          away_player:,
          scores: [ [ :home, 60 ], [ :home, 150 ], [ :home, 180 ], [ :home, 210 ], [ :home, 240 ] ],
          final_score: [ 5, 0 ]
        )

        result = described_class.call(season:)

        biggest_domination = result.dig(:records, :rows).find { |row| row.fetch(:key) == "biggest_domination" }

        expect(biggest_domination).to include(value: "+5 / 5:0", match: latest_tied_match)
      end
    end
  end

  def create_completed_match(season:, played_on:, home_player:, away_player:, scores:, final_score:)
    match_day = create(:match_day, season:, status: "finished", played_on:)
    team_setup = create(:team_setup, match_day:)
    home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Zieloni")
    away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Czarni")
    home_team_player = create(:team_player, team: home_team, player: home_player)
    away_team_player = create(:team_player, team: away_team, player: away_player)
    start_time = Time.zone.local(2026, 7, played_on.day, 18, 0, 0)
    match = create(:match, match_day:, home_team:, away_team:, started_at: start_time, finished_at: start_time + scores.last.second.seconds, home_score: final_score.first, away_score: final_score.second)

    scores.each do |team_key, seconds|
      create(
        :match_goal,
        match:,
        scoring_team: team_key == :home ? home_team : away_team,
        scorer_team_player: team_key == :home ? home_team_player : away_team_player,
        scored_at: start_time + seconds.seconds
      )
    end

    match
  end
end
