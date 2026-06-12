require "rails_helper"

RSpec.describe Matches::StartMatch do
  describe ".call" do
    it "starts a prepared match and moves the match day in progress" do
      match_day = create(:match_day, status: "ready")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: home_team, player: create(:player))
      create(:team_player, team: away_team, player: create(:player, nickname: "away", phone: "+48999999998"))
      match = create(:match, match_day:, home_team:, away_team:, started_at: nil)

      travel_to Time.zone.parse("2026-06-19 19:15:00") do
        result = described_class.call(match:)

        expect(result).to be(true)
        expect(match.reload.started_at).to eq(Time.zone.parse("2026-06-19 19:15:00"))
        expect(match_day.reload.status).to eq("in_progress")
      end
    end

    it "returns false when the lineup is not ready" do
      match_day = create(:match_day, status: "ready")
      match = create(:match, match_day:, started_at: nil)

      expect(described_class.call(match:)).to be(false)
      expect(match.reload.started_at).to be_nil
    end
  end
end
