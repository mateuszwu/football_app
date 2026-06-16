require "rails_helper"

RSpec.describe "Players" do
  def encrypted_cookie_value(value)
    request = ActionDispatch::Request.new(Rails.application.env_config.deep_dup)
    jar = ActionDispatch::Cookies::CookieJar.build(request, {})
    jar.encrypted[:pending_player_edit_token] = value
    jar[:pending_player_edit_token]
  end

  def decrypted_cookie_value(value)
    request = ActionDispatch::Request.new(Rails.application.env_config.deep_dup)
    jar = ActionDispatch::Cookies::CookieJar.build(request, { "pending_player_edit_token" => value })
    jar.encrypted[:pending_player_edit_token]
  end

  describe "GET /players/new" do
    it "renders the public submission form without private phone data" do
      get "/players/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Zgloszenie zawodnika")
      expect(response.body).to include("Imie i nazwisko")
      expect(response.body).to include("Nick")
      expect(response.body).to include("Telefon")
      expect(response.body).to include("Opis")
      expect(response.body).to include("Rola")
      expect(response.body).not_to include("+48")
    end
  end

  describe "POST /players" do
    context "when the submission is valid" do
      it "creates a pending player, writes an encrypted edit cookie, and redirects to the edit form" do
        post "/players", params: {
          player: {
            name: "Adam Nowak",
            nickname: "adam",
            phone: "+48111111111",
            description: "Solid defender",
            role_code: "DEF"
          }
        }

        player = Player.order(:created_at).last

        expect(response).to redirect_to("/players/#{player.id}/edit")
        expect(flash[:notice]).to eq("Zgloszenie zawodnika zostalo zapisane i czeka na akceptacje.")
        expect(player.name).to eq("Adam Nowak")
        expect(player.nickname).to eq("adam")
        expect(player.phone).to eq("+48111111111")
        expect(player.description).to eq("Solid defender")
        expect(player.role_code).to eq("DEF")
        expect(player.approval_status).to eq("pending")
        expect(player.active).to eq(true)
        encrypted_cookie = cookies[:pending_player_edit_token]

        expect(encrypted_cookie).to be_present

        payload, = JWT.decode(
          decrypted_cookie_value(encrypted_cookie),
          Rails.application.secret_key_base,
          true,
          algorithm: Players::GenerateEditToken::ALGORITHM
        )

        expect(payload["player_id"]).to eq(player.id)
        expect(payload["purpose"]).to eq(Players::GenerateEditToken::PURPOSE)
        expect(payload["exp"]).to be_within(5).of(Players::GenerateEditToken::EXPIRATION.from_now.to_i)
        expect(response.location).not_to include("token")
        expect(Array(response.headers["Set-Cookie"]).join("\n")).to include("httponly")
      end
    end

    context "when the submission is invalid" do
      it "renders validation errors without creating the player" do
        post "/players", params: {
          player: {
            name: "",
            nickname: "",
            phone: "",
            description: "",
            role_code: "COACH"
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Popraw bledy formularza:")
        expect(response.body).to include("Name can&#39;t be blank")
        expect(response.body).to include("Nickname can&#39;t be blank")
        expect(response.body).to include("Phone can&#39;t be blank")
        expect(response.body).to include("Description can&#39;t be blank")
        expect(response.body).to include("Role code is not included in the list")
        expect(cookies[:pending_player_edit_token]).to be_nil
        expect(Player.count).to eq(0)
      end
    end
  end

  describe "GET /players/:id/edit" do
    context "when the cookie belongs to the same pending player" do
      it "renders the edit form" do
        player = create(:player, approval_status: "pending", active: true)
        cookies[:pending_player_edit_token] = encrypted_cookie_value(Players::GenerateEditToken.call(player: player))

        get "/players/#{player.id}/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Edytuj zgloszenie zawodnika")
        expect(response.body).to include(player.name)
        expect(response.body).to include(player.nickname)
        expect(response.body).to include(player.phone)
      end
    end

    context "when the cookie belongs to another player" do
      it "redirects away from the edit page" do
        player = create(:player, approval_status: "pending", active: true)
        other_player = create(:player, approval_status: "pending", active: true)
        cookies[:pending_player_edit_token] = encrypted_cookie_value(Players::GenerateEditToken.call(player: other_player))

        get "/players/#{player.id}/edit"

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostepu do edycji tego zgloszenia.")
      end
    end

    context "when the cookie is missing" do
      it "redirects away from the edit page" do
        player = create(:player, approval_status: "pending", active: true)

        get "/players/#{player.id}/edit"

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostepu do edycji tego zgloszenia.")
      end
    end

    context "when the cookie token is expired" do
      it "redirects away from the edit page" do
        player = create(:player, approval_status: "pending", active: true)
        expired_token = JWT.encode(
          {
            "player_id" => player.id,
            "purpose" => Players::GenerateEditToken::PURPOSE,
            "exp" => 1.minute.ago.to_i
          },
          Rails.application.secret_key_base,
          Players::GenerateEditToken::ALGORITHM
        )
        cookies[:pending_player_edit_token] = encrypted_cookie_value(expired_token)

        get "/players/#{player.id}/edit"

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostepu do edycji tego zgloszenia.")
      end
    end

    context "when the player is no longer pending" do
      it "redirects away from the edit page" do
        player = create(:player, approval_status: "approved", active: true)
        cookies[:pending_player_edit_token] = encrypted_cookie_value(Players::GenerateEditToken.call(player: player))

        get "/players/#{player.id}/edit"

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostepu do edycji tego zgloszenia.")
      end
    end
  end

  describe "PATCH /players/:id" do
    context "when the cookie belongs to the same pending player" do
      it "updates the player submission" do
        player = create(:player, approval_status: "pending", active: true, name: "Old Name", nickname: "oldnick")
        cookies[:pending_player_edit_token] = encrypted_cookie_value(Players::GenerateEditToken.call(player: player))

        patch "/players/#{player.id}", params: {
          player: {
            name: "New Name",
            nickname: "newnick",
            phone: player.phone,
            description: "Updated description",
            role_code: "MID"
          }
        }

        expect(response).to redirect_to("/players/#{player.id}/edit")
        expect(flash[:notice]).to eq("Zgloszenie zawodnika zostalo zaktualizowane.")
        expect(player.reload.name).to eq("New Name")
        expect(player.nickname).to eq("newnick")
        expect(player.description).to eq("Updated description")
        expect(player.role_code).to eq("MID")
        expect(player.approval_status).to eq("pending")
      end
    end

    context "when the cookie is invalid" do
      it "does not update the player submission" do
        player = create(:player, approval_status: "pending", active: true, name: "Old Name")
        cookies[:pending_player_edit_token] = encrypted_cookie_value("not-a-token")

        patch "/players/#{player.id}", params: {
          player: {
            name: "New Name",
            nickname: player.nickname,
            phone: player.phone,
            description: player.description,
            role_code: player.role_code
          }
        }

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostepu do edycji tego zgloszenia.")
        expect(player.reload.name).to eq("Old Name")
      end
    end

    context "when the player is no longer pending" do
      it "does not update the player submission" do
        player = create(:player, approval_status: "approved", active: true, name: "Old Name")
        cookies[:pending_player_edit_token] = encrypted_cookie_value(Players::GenerateEditToken.call(player: player))

        patch "/players/#{player.id}", params: {
          player: {
            name: "New Name",
            nickname: player.nickname,
            phone: player.phone,
            description: player.description,
            role_code: player.role_code
          }
        }

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostepu do edycji tego zgloszenia.")
        expect(player.reload.name).to eq("Old Name")
      end
    end
  end

  describe "GET /players/:id" do
    context "when the player is approved and active" do
      it "renders the public profile with season-filtered stats and without private phone data" do
        player = create(
          :player,
          name: "Adam Nowak",
          nickname: "adam",
          phone: "+48111111111",
          description: "Solid defender",
          role_code: "DEF",
          approval_status: "approved",
          active: true
        )
        spring = create(:season, name: "Spring 2026", starts_on: Date.new(2026, 3, 1))
        summer = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1))
        spring_match_day = create(:match_day, played_on: Date.new(2026, 5, 22), status: "finished", season: spring)
        summer_match_day = create(:match_day, played_on: Date.new(2026, 5, 29), status: "finished", season: summer)
        spring_setup = create(:team_setup, match_day: spring_match_day)
        summer_setup = create(:team_setup, match_day: summer_match_day)
        spring_team = create(:team, team_setup: spring_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
        spring_opponent = create(:team, team_setup: spring_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
        summer_team = create(:team, team_setup: summer_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
        summer_opponent = create(:team, team_setup: summer_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
        create(:team_player, player: player, team: spring_team)
        create(:team_player, player: player, team: summer_team)
        create(:match, match_day: spring_match_day, home_team: spring_team, away_team: spring_opponent, home_score: 0, away_score: 1, finished_at: Time.zone.parse("2026-05-22 20:00:00"))
        create(:match, match_day: summer_match_day, home_team: summer_team, away_team: summer_opponent, home_score: 2, away_score: 1, finished_at: Time.zone.parse("2026-05-29 20:00:00"))
        create(:player_season_stat, player: player, season: spring, elo: 1004, goals: 1, assists: 0, mvp_votes_count: 0, def_votes_count: 2)
        create(:player_season_stat, player: player, season: summer, elo: 1020, goals: 3, assists: 2, mvp_votes_count: 4, def_votes_count: 1)

        get "/players/#{player.id}", params: { season_id: summer.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("adam")
        expect(response.body).to include("DEF")
        expect(response.body).to include("Solid defender")
        expect(response.body).to include("Elo globalne:")
        expect(response.body).to include("Elo sezonu Summer 2026:")
        expect(response.body).to include("1020")
        expect(response.body).to include("Mecze")
        expect(response.body).to include("Bilans")
        expect(response.body).to include("Win rate")
        expect(response.body).to include("1-0-0")
        expect(response.body).to include("100%")
        expect(response.body).to include("3 / 2")
        expect(response.body).to include("4 / 1")
        expect(response.body).to include("Historia meczow")
        expect(response.body).to include("2026-05-29")
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("2:1")
        expect(response.body).to include("win")
        expect(response.body).to include("Sezon")
        expect(response.body).to include("Filtruj")
        expect(response.body).not_to include("2026-05-22")
        expect(response.body).not_to include("0:1")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the player has not played any match days" do
      it "renders an empty history state" do
        player = create(:player, approval_status: "approved", active: true)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak rozegranych meczow.")
      end
    end

    context "when the player is pending approval" do
      it "does not render the public profile" do
        player = create(:player, approval_status: "pending", active: true)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the player is inactive" do
      it "does not render the public profile" do
        player = create(:player, approval_status: "approved", active: false)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
