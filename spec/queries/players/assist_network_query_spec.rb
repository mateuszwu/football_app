require "rails_helper"

RSpec.describe Players::AssistNetworkQuery do
  describe ".call" do
    it "returns assist links ordered by assist count" do
      season = create(:season, name: "Summer 2026")
      match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5), status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      assistant = create(:player, name: "Adam")
      scorer = create(:player, name: "Marek")
      secondary_scorer = create(:player, name: "Zed")
      assistant_team_player = create(:team_player, team: home_team, player: assistant)
      scorer_team_player = create(:team_player, team: home_team, player: scorer)
      secondary_scorer_team_player = create(:team_player, team: home_team, player: secondary_scorer)
      create(:team_player, team: away_team, player: create(:player, name: "Opponent"))
      match = create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 0, finished_at: Time.zone.parse("2026-06-05 20:00:00"))
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player: scorer_team_player, assistant_team_player: assistant_team_player, scored_at: Time.zone.parse("2026-06-05 18:10:00"))
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player: scorer_team_player, assistant_team_player: assistant_team_player, scored_at: Time.zone.parse("2026-06-05 18:20:00"))
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player: secondary_scorer_team_player, assistant_team_player: assistant_team_player, scored_at: Time.zone.parse("2026-06-05 18:30:00"))

      result = described_class.call(season:)

      expect(result.map { |edge| [ edge.assistant.name, edge.scorer.name, edge.assists_count ] }).to eq(
        [
          [ "Adam", "Marek", 2 ],
          [ "Adam", "Zed", 1 ]
        ]
      )
    end
  end
end
