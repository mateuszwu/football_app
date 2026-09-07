require "rails_helper"

RSpec.describe StatisticsHelper do
  describe "#statistics_sorted_rows" do
    let(:player) { build_stubbed(:player, name: "Adam Demo") }

    it "sorts row values for every statistics table" do
      expect(
        helper.statistics_sorted_rows(
          [ { key: "latest_first_goal", subject: "Zieloni", value: "00:30" },
            { key: "fastest_goal", subject: "Czarni", value: "00:14" } ],
          tab: "tempo", sort_column: "value", sort_direction: "asc"
        ).map { |row| row.fetch(:value) }
      ).to eq([ "00:14", "00:30" ])

      expect(
        helper.statistics_sorted_rows(
          [ { key: "latest_first_goal", subject: "Zieloni", value: "00:30" },
            { key: "fastest_goal", subject: "Czarni", value: "00:14" } ],
          tab: "records", sort_column: "match_or_player", sort_direction: "asc"
        ).map { |row| row.fetch(:subject) }
      ).to eq([ "Czarni", "Zieloni" ])

      first_goal_rows = [
        { player:, first_goals: 1, matches: 2, first_goal_rate: 50, win_rate_after_first_goal: 100 },
        { player: build_stubbed(:player, name: "Bartek Demo"), first_goals: 2, matches: 1, first_goal_rate: 200, win_rate_after_first_goal: 0 }
      ]
      expect(helper.statistics_sorted_rows(first_goal_rows, tab: "first_goal", sort_column: "player", sort_direction: "asc").first.fetch(:player)).to eq(player)
      expect(helper.statistics_sorted_rows(first_goal_rows, tab: "first_goal", sort_column: "first_goals", sort_direction: "desc").first.fetch(:first_goals)).to eq(2)

      comeback_rows = [
        { deficit: "0:2", situations: 1, comeback_wins: 1, comeback_rate: 100, examples: [ { subject: "Zieloni" } ] },
        { deficit: "0:1", situations: 2, comeback_wins: 1, comeback_rate: 50, examples: [ { subject: "Czarni" } ] }
      ]
      expect(helper.statistics_sorted_rows(comeback_rows, tab: "comebacks", sort_column: "deficit", sort_direction: "asc").first.fetch(:deficit)).to eq("0:1")
      expect(helper.statistics_sorted_rows(comeback_rows, tab: "comebacks", sort_column: "example_match", sort_direction: "asc").first.fetch(:examples).first.fetch(:subject)).to eq("Czarni")
      expect(helper.statistics_sorted_rows(comeback_rows, tab: "comebacks", sort_column: "situations", sort_direction: "desc").first.fetch(:situations)).to eq(2)

      score_state_rows = [
        { state: "1:0", occurrences: 2, leader_wins: 1, hold_rate: 50, comeback_count: 1 },
        { state: "0:1", occurrences: 1, leader_wins: 1, hold_rate: 100, comeback_count: 0 }
      ]
      expect(helper.statistics_sorted_rows(score_state_rows, tab: "score_states", sort_column: "state", sort_direction: "asc").first.fetch(:state)).to eq("0:1")
      expect(helper.statistics_sorted_rows(score_state_rows, tab: "score_states", sort_column: "occurrences", sort_direction: "desc").first.fetch(:occurrences)).to eq(2)

      clutch_rows = [
        { player:, opening_goals: 1, closing_goals: 0, go_ahead_goals: 0, equalizer_goals: 0, goals_when_tied: 0, comeback_contribution: 0 },
        { player: build_stubbed(:player, name: "Bartek Demo"), opening_goals: 0, closing_goals: 1, go_ahead_goals: 0, equalizer_goals: 0, goals_when_tied: 0, comeback_contribution: 0 }
      ]
      expect(helper.statistics_sorted_rows(clutch_rows, tab: "clutch", sort_column: "player", sort_direction: "asc").first.fetch(:player)).to eq(player)
      expect(helper.statistics_sorted_rows(clutch_rows, tab: "clutch", sort_column: "closing_goals", sort_direction: "desc").first.fetch(:closing_goals)).to eq(1)
    end

    it "ignores unsupported sorting and exposes accessible sort state" do
      rows = [ { player:, first_goals: 1, matches: 1, first_goal_rate: 100, win_rate_after_first_goal: 100 } ]

      expect(helper.statistics_sorted_rows(rows, tab: "first_goal", sort_column: "unknown", sort_direction: "asc")).to eq(rows)
      expect(helper.statistics_sorted_rows(rows, tab: "first_goal", sort_column: "first_goals", sort_direction: "unknown")).to eq(rows)
      expect(helper.statistics_sort_aria("first_goal", :first_goals, "first_goals", "asc")).to eq("ascending")
      expect(helper.statistics_sort_aria("first_goal", :first_goals, "first_goals", "desc")).to eq("descending")
      expect(helper.statistics_sort_aria("first_goal", :first_goals, "first_goals", nil)).to eq("none")

      season = build_stubbed(:season, id: 1)
      link = helper.statistics_sort_link(season:, tab: "first_goal", column: :first_goals, sort_column: "first_goals", sort_direction: "desc") { "Pierwsze gole" }

      expect(link).to include("sort_direction=asc")
      expect(link).to include("↓")
      expect(helper.send(:statistics_value_sort_key, "gole")).to eq("gole")
    end
  end
end
