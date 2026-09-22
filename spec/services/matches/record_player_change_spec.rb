require "rails_helper"

RSpec.describe Matches::RecordPlayerChange do
  describe ".call" do
    context "when a player changes teams during an in-progress match" do
      it "records the change and makes the target team available for later events" do
        match_day = create(:match_day, status: "in_progress")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Team A")
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Team B")
        player = create(:player, name: "Switch Player", nickname: "switch-player")
        opponent = create(:player, name: "Opponent", nickname: "opponent")
        create(:match_day_player, match_day:, player:)
        create(:match_day_player, match_day:, player: opponent)
        create(:team_player, team: home_team, player:)
        create(:team_player, team: away_team, player: opponent)
        match = create(
          :match,
          match_day:,
          home_team:,
          away_team:,
          started_at: Time.zone.parse("2026-06-19 19:00:00")
        )
        changed_at = Time.zone.parse("2026-06-19 19:15:00")

        result = described_class.call(match:, player:, from_team: home_team, to_team: away_team, occurred_at: changed_at)

        expect(result).to be_persisted
        expect(result).to have_attributes(
          event_type: MatchPlayerChange::EVENT_TEAM_CHANGE,
          from_team: home_team,
          to_team: away_team,
          occurred_at: changed_at
        )
        expect(away_team.reload.players).to include(player)
        expect(match.reload.player_team_at(player, occurred_at: changed_at - 1.second)).to eq(home_team)
        expect(match.player_team_at(player, occurred_at: changed_at)).to eq(away_team)
      end
    end

    context "when a player leaves the pitch" do
      it "records an out event and excludes the player from the final team" do
        match_day = create(:match_day, status: "in_progress")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        player = create(:player, nickname: "leaving-player")
        opponent = create(:player, nickname: "leaving-opponent")
        [ player, opponent ].each { |candidate| create(:match_day_player, match_day:, player: candidate) }
        create(:team_player, team: home_team, player:)
        create(:team_player, team: away_team, player: opponent)
        match = create(:match, match_day:, home_team:, away_team:, started_at: Time.zone.parse("2026-06-19 19:00:00"))

        result = described_class.call(
          match:,
          player:,
          from_team: home_team,
          to_team: nil,
          occurred_at: Time.zone.parse("2026-06-19 19:20:00")
        )

        expect(result.event_type).to eq(MatchPlayerChange::EVENT_SUBSTITUTION_OUT)
        expect(match.reload.final_players_for(home_team)).not_to include(player)
      end
    end

    context "when the source team is not the player's current team" do
      it "rejects the change" do
        match_day = create(:match_day, status: "in_progress")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        player = create(:player, nickname: "wrong-source-player")
        create(:match_day_player, match_day:, player:)
        create(:team_player, team: home_team, player:)
        match = create(:match, match_day:, home_team:, away_team:, started_at: Time.zone.parse("2026-06-19 19:00:00"))

        result = described_class.call(
          match:,
          player:,
          from_team: away_team,
          to_team: home_team,
          occurred_at: Time.zone.parse("2026-06-19 19:20:00")
        )

        expect(result).to be(false)
        expect(match.match_player_changes).to be_empty
      end
    end
  end
end
