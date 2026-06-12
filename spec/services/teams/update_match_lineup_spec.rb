require "rails_helper"

RSpec.describe Teams::UpdateMatchLineup do
  describe ".call" do
    it "rebuilds the pre-match lineup and updates home and away teams" do
      match_day = create(:match_day)
      team_setup = create(:team_setup, match_day:)
      first_player = create(:player)
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
      third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997")
      create(:match_day_player, match_day:, player: first_player)
      create(:match_day_player, match_day:, player: second_player)
      create(:match_day_player, match_day:, player: third_player)

      home_team = create(:team, team_setup:, match: nil, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, match: nil, name: "Team B", team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: home_team, player: first_player)
      create(:team_player, team: away_team, player: second_player)
      match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
      home_team.update!(match:)
      away_team.update!(match:)

      result = described_class.call(
        match: match,
        teams_data: [
          { id: home_team.id, name: "Team A", player_ids: [ second_player.id.to_s ] },
          { id: away_team.id, name: "Team B", player_ids: [ first_player.id.to_s ] },
          { name: "Waiting", player_ids: [ third_player.id.to_s ] }
        ]
      )

      expect(result).to be(true)
      expect(match.reload.home_team.players).to contain_exactly(second_player)
      expect(match.away_team.players).to contain_exactly(first_player)
      expect(match.teams.find_by!(name: "Waiting").players).to contain_exactly(third_player)
      expect(match.teams.find_by!(name: "Waiting")).not_to be_playing
    end

    it "returns false when a player is left unassigned" do
      match_day = create(:match_day)
      team_setup = create(:team_setup, match_day:)
      first_player = create(:player)
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
      create(:match_day_player, match_day:, player: first_player)
      create(:match_day_player, match_day:, player: second_player)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
      home_team.update!(match:)
      away_team.update!(match:)

      result = described_class.call(
        match: match,
        teams_data: [
          { id: home_team.id, name: "Team A", player_ids: [ first_player.id.to_s ] },
          { id: away_team.id, name: "Team B", player_ids: [] }
        ]
      )

      expect(result).to be(false)
      expect(match.errors[:base]).to include("All selected match day players must be assigned before the match starts")
    end
  end
end
