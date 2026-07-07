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
        expect(result.dig(:comebacks, :threshold_rows).find { |row| row.fetch(:deficit) == "0:2" }).to include(comeback_wins: 1)
        expect(result.dig(:score_states, :rows).map { |row| row.fetch(:state) }).to include("2:0", "4:0")
        expect(result.fetch(:clutch_players).find { |row| row.fetch(:player) == adam }).to include(closing_goals: 2)
        expect(result.dig(:chart_data, :match_durations, :labels)).to include("2026-07-01 · ##{first_match.id}")
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
