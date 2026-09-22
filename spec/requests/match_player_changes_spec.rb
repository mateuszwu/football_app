require "rails_helper"

RSpec.describe "Match player changes" do
  describe "POST /matches/:match_id/player_changes" do
    it "requires admin access" do
      match = create(:match, started_at: Time.zone.parse("2026-06-19 19:00:00"))

      post "/matches/#{match.id}/player_changes", params: {
        match_player_change: {
          player_id: create(:player).id,
          from_team_id: match.home_team.id,
          to_team_id: match.away_team.id,
          occurred_at: "2026-06-19T19:10"
        }
      }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Admin access required")
      expect(match.match_player_changes).to be_empty
    end

    it "records a team switch for an admin" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day, status: "in_progress")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Team A")
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Team B")
        player = create(:player, name: "Changing Player", nickname: "changing-player")
        opponent = create(:player, name: "Opposing Player", nickname: "opposing-player")
        [ player, opponent ].each { |candidate| create(:match_day_player, match_day:, player: candidate) }
        create(:team_player, team: home_team, player:)
        create(:team_player, team: away_team, player: opponent)
        match = create(:match, match_day:, home_team:, away_team:, started_at: Time.zone.parse("2026-06-19 19:00:00"))
        post "/admin/session", params: { password: "secret-password" }

        post "/matches/#{match.id}/player_changes", params: {
          match_player_change: {
            player_id: player.id,
            from_team_id: home_team.id,
            to_team_id: away_team.id,
            occurred_at: "2026-06-19T19:10"
          }
        }

        change = match.match_player_changes.order(:id).last
        expect(response).to redirect_to(match_path(match))
        expect(flash[:notice]).to eq("Player change recorded")
        expect(change).to have_attributes(from_team: home_team, to_team: away_team, player:)
        expect(away_team.reload.players).to include(player)
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end
  end
end
