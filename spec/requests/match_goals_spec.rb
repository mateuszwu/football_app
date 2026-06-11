require "rails_helper"

RSpec.describe "Match goals" do
  describe "POST /matches/:match_id/goals" do
    context "when the visitor is not signed in as admin" do
      it "does not create a goal" do
        match = create(:match, started_at: Time.zone.parse("2026-06-19 19:15:00"))
        player = create(:player, name: "Scorer", nickname: "scorer", phone: "+48123456789")
        create(:team_player, team: match.home_team, player: player)

        post "/matches/#{match.id}/goals", params: {
          match_goal: {
            scoring_team_id: match.home_team.id,
            scorer_id: player.id
          }
        }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
        expect(MatchGoal.count).to eq(0)
        expect(match.reload.home_score).to eq(0)
      end
    end

    context "when the visitor is signed in as admin" do
      it "creates a goal and increments the score" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match = create(:match, started_at: Time.zone.parse("2026-06-19 19:15:00"))
          player = create(:player, name: "Scorer", nickname: "scorer", phone: "+48123456789")
          create(:team_player, team: match.home_team, player: player)

          post "/admin/session", params: { password: "secret-password" }

          post "/matches/#{match.id}/goals", params: {
            match_goal: {
              scoring_team_id: match.home_team.id,
              scorer_id: player.id
            }
          }

          expect(response).to redirect_to(match_path(match))
          expect(flash[:notice]).to eq("Goal added")
          expect(match.reload.home_score).to eq(1)
          expect(match.away_score).to eq(0)

          goal = MatchGoal.find_by!(match:, scorer: player)
          expect(goal.scoring_team).to eq(match.home_team)
          expect(goal.scored_at).to be_present
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end

      it "creates a goal with an assistant" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match = create(:match, started_at: Time.zone.parse("2026-06-19 19:15:00"))
          scorer = create(:player, name: "Scorer", nickname: "scorer", phone: "+48123456789")
          assistant = create(:player, name: "Assistant", nickname: "assistant", phone: "+48987654321")
          create(:team_player, team: match.home_team, player: scorer)
          create(:team_player, team: match.home_team, player: assistant)

          post "/admin/session", params: { password: "secret-password" }

          post "/matches/#{match.id}/goals", params: {
            match_goal: {
              scoring_team_id: match.home_team.id,
              scorer_id: scorer.id,
              assistant_id: assistant.id
            }
          }

          expect(response).to redirect_to(match_path(match))
          expect(flash[:notice]).to eq("Goal added")
          expect(match.reload.home_score).to eq(1)

          goal = MatchGoal.find_by!(match:, scorer:)
          expect(goal.assistant).to eq(assistant)
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end

      it "rejects goals when the assistant is the scorer" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match = create(:match, started_at: Time.zone.parse("2026-06-19 19:15:00"))
          scorer = create(:player, name: "Scorer", nickname: "scorer", phone: "+48123456789")
          create(:team_player, team: match.home_team, player: scorer)

          post "/admin/session", params: { password: "secret-password" }

          post "/matches/#{match.id}/goals", params: {
            match_goal: {
              scoring_team_id: match.home_team.id,
              scorer_id: scorer.id,
              assistant_id: scorer.id
            }
          }

          expect(response).to redirect_to(match_path(match))
          expect(flash[:alert]).to eq("Could not add goal")
          expect(MatchGoal.count).to eq(0)
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end

      it "rejects goals when the match is not in progress" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match = create(:match, started_at: nil)
          player = create(:player, name: "Scorer", nickname: "scorer", phone: "+48123456789")
          create(:team_player, team: match.home_team, player: player)

          post "/admin/session", params: { password: "secret-password" }

          post "/matches/#{match.id}/goals", params: {
            match_goal: {
              scoring_team_id: match.home_team.id,
              scorer_id: player.id
            }
          }

          expect(response).to redirect_to(match_path(match))
          expect(flash[:alert]).to eq("Could not add goal")
          expect(MatchGoal.count).to eq(0)
          expect(match.reload.home_score).to eq(0)
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
end
