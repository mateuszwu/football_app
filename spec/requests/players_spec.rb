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
      expect(response.body).to include("Zgłoszenie zawodnika")
      expect(response.body).to include("Imię i nazwisko")
      expect(response.body).to include("Nick")
      expect(response.body).to include("Telefon")
      expect(response.body).to include("Opis")
      expect(response.body).to include("Rola")
      expect(response.body).not_to include("+48")
    end
  end

  describe "GET /players" do
    it "renders a public roster directory with filters and without private phone data" do
      season = create(:season, name: "Summer 2026")
      player = create(
        :player,
        name: "Adam Nowak",
        nickname: "adam",
        phone: "+48111111111",
        role_code: "DEF",
        approval_status: "approved",
        active: true,
        elo: 1008
      )
      hidden_player = create(:player, name: "Hidden Pending", phone: "+48222222222", approval_status: "pending", active: true)
      create(:player_season_stat, player:, season:, elo: 1040, goals: 2, assists: 1)
      match_day = create(:match_day, season:, played_on: Date.new(2026, 7, 1), status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
      team_player = create(:team_player, player:, team: home_team)
      create(:team_player, team: away_team)
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: Time.zone.parse("2026-07-01 20:00:00"))
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player: team_player)

      get "/players", params: { season_id: season.id, role: "DEF", q: "adam" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Zawodnicy")
      expect(response.body).to include("Szukaj po imieniu albo nicku")
      expect(response.body).to include("Adam Nowak")
      expect(response.body).to include("@adam")
      expect(response.body).to include("Obrońca")
      expect(response.body).to include("1040")
      expect(response.body).to include("Profil zawodnika")
      expect(response.body).to include("/players/#{player.id}")
      expect(response.body).not_to include('href="/players/new"')
      expect(response.body).to include("Dołącz")
      expect(response.body).to include("site-nav__link--disabled")
      expect(response.body).not_to include("KADRA")
      expect(response.body).not_to include("Dołącz do gry")
      expect(response.body).not_to include("players-directory-join")
      expect(response.body).not_to include(hidden_player.name)
      expect(response.body).not_to include("+48111111111")
      expect(response.body).not_to include("+48222222222")
      expect(response.body).not_to include("phone")
    end

    it "renders an empty roster state when filters have no matches" do
      create(:player, name: "Adam Nowak", nickname: "adam", approval_status: "approved", active: true)

      get "/players", params: { q: "marek" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Brak zawodników")
      expect(response.body).to include("Nie znaleziono aktywnych zatwierdzonych zawodników dla tych filtrów.")
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
        expect(flash[:notice]).to eq("Zgłoszenie zawodnika zostało zapisane i czeka na akceptację.")
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

      it "creates a player without a phone number" do
        post "/players", params: {
          player: {
            name: "Jan Kowalski",
            nickname: "jan",
            phone: "",
            description: "Regular player",
            role_code: "ANY"
          }
        }

        player = Player.find_by!(nickname: "jan")

        expect(response).to redirect_to("/players/#{player.id}/edit")
        expect(player.phone).to be_nil
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
        expect(response.body).to include("Popraw błędy formularza:")
        expect(response.body).to include("Name can&#39;t be blank")
        expect(response.body).to include("Nickname can&#39;t be blank")
        expect(response.body).not_to include("Phone can&#39;t be blank")
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
        expect(response.body).to include("Edytuj zgłoszenie zawodnika")
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
        expect(flash[:alert]).to eq("Brak dostępu do edycji tego zgłoszenia.")
      end
    end

    context "when the cookie is missing" do
      it "redirects away from the edit page" do
        player = create(:player, approval_status: "pending", active: true)

        get "/players/#{player.id}/edit"

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostępu do edycji tego zgłoszenia.")
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
        expect(flash[:alert]).to eq("Brak dostępu do edycji tego zgłoszenia.")
      end
    end

    context "when the player is no longer pending" do
      it "redirects away from the edit page" do
        player = create(:player, approval_status: "approved", active: true)
        cookies[:pending_player_edit_token] = encrypted_cookie_value(Players::GenerateEditToken.call(player: player))

        get "/players/#{player.id}/edit"

        expect(response).to redirect_to("/players/new")
        expect(flash[:alert]).to eq("Brak dostępu do edycji tego zgłoszenia.")
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
        expect(flash[:notice]).to eq("Zgłoszenie zawodnika zostało zaktualizowane.")
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
        expect(flash[:alert]).to eq("Brak dostępu do edycji tego zgłoszenia.")
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
        expect(flash[:alert]).to eq("Brak dostępu do edycji tego zgłoszenia.")
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
        summer_team_player = create(:team_player, player: player, team: summer_team)
        summer_assistant = create(:team_player, team: summer_team)
        create(:team_player, team: summer_opponent)
        create(:match, match_day: spring_match_day, home_team: spring_team, away_team: spring_opponent, home_score: 0, away_score: 1, finished_at: Time.zone.parse("2026-05-22 20:00:00"))
        summer_match = create(:match, match_day: summer_match_day, home_team: summer_team, away_team: summer_opponent, home_score: 2, away_score: 1, finished_at: Time.zone.parse("2026-05-29 20:00:00"))
        create(:match_goal, match: summer_match, scoring_team: summer_team, scorer_team_player: summer_team_player, assistant_team_player: summer_assistant)
        create(:match_goal, match: summer_match, scoring_team: summer_opponent, scorer_team_player: summer_team_player, own_goal: true)
        create(:player_season_stat, player: player, season: spring, elo: 1004, goals: 1, assists: 0, mvp_votes_count: 0, def_votes_count: 2)
        create(:player_season_stat, player: player, season: summer, elo: 1020, goals: 3, assists: 2, mvp_votes_count: 4, def_votes_count: 1)
        create(
          :player_rating_change,
          player:,
          season: summer,
          match_day: summer_match_day,
          match: summer_match,
          old_elo_score: 1000,
          elo_delta: 20,
          new_elo_score: 1020
        )

        get "/players/#{player.id}", params: { season_id: summer.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("@adam")
        expect(response.body).to include("Obrońca")
        expect(response.body).to include("Solid defender")
        expect(response.body).to include("Powrót do zawodników")
        expect(response.body).to include("Podsumowanie")
        expect(response.body).to include("Statystyki")
        expect(response.body).to include("Mecze")
        expect(response.body).to include("Wykresy")
        expect(response.body).to include("Historia ELO")
        expect(response.body).to include("Synergia")
        expect(response.body).to include("MVP / DEF")
        expect(response.body).to include('id="player_profile_results"')
        expect(response.body).to include("leaderboards-tabs--responsive")
        expect(response.body).to include('role="tablist"')
        expect(response.body).to include('data-turbo-frame="player_profile_results"')
        expect(response.body).to include("1020")
        expect(response.body).to include("Mecze")
        expect(response.body).to include("Wygrane")
        expect(response.body).to include("Remisy")
        expect(response.body).to include("Porażki")
        expect(response.body).to include("1W · 0R · 0P")
        expect(response.body).to include("100%")
        expect(response.body).to include("Samobóje")
        expect(response.body).to include("Najlepsza seria wygranych")
        expect(response.body).to include("Gole / Asysty")
        expect(response.body).to include("G+A")
        expect(response.body).to include("Ostatnie mecze")
        expect(response.body).to include("Bilans meczów")
        expect(response.body).to include("Zobacz mecz")
        match_links = Nokogiri::HTML(response.body).css("a").select { |link| link.text.strip == "Zobacz mecz" }
        expect(match_links).not_to be_empty
        expect(match_links).to all(satisfy { |link| link["data-turbo-frame"] == "_top" })
        expect(response.body).to include("2026-05-29")
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("2:1")
        expect(response.body).to include(">W</span>")
        expect(response.body).to include("Sezon")
        expect(response.body).not_to include("2026-05-22")
        expect(response.body).not_to include("0:1")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("phone")
      end

      it "renders the ELO tab without the old help card" do
        player = create(:player, name: "Adam Nowak", approval_status: "approved", active: true)

        get "/players/#{player.id}", params: { tab: "elo" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Historia ELO")
        expect(response.body).not_to include("Jak czytać ELO")
        expect(response.body).not_to include("Historia zmian ELO")
      end

      it "renders direct mutual assists on the synergy tab" do
        season = create(:season, name: "Summer 2026")
        adam = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Nowak", nickname: "bartek", phone: "+48222222222", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Nowak", nickname: "cezary", phone: "+48333333333", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 19), status: "finished")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        adam_team_player = create(:team_player, team: home_team, player: adam)
        bartek_team_player = create(:team_player, team: home_team, player: bartek)
        cezary_team_player = create(:team_player, team: home_team, player: cezary)
        create(:team_player, team: away_team, player: create(:player, approval_status: "approved", active: true))
        match = create(
          :match,
          match_day:,
          home_team:,
          away_team:,
          home_score: 2,
          away_score: 0,
          status: Match::STATUS_FINISHED,
          finished_at: Time.zone.parse("2026-06-19 20:00:00")
        )
        create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: bartek_team_player)
        create(:match_goal, match:, scoring_team: home_team, scorer_team_player: cezary_team_player, assistant_team_player: adam_team_player)

        get "/players/#{adam.id}", params: { season_id: season.id, tab: "synergy" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Asysty między sobą")
        expect(response.body).to include("Bartek Nowak")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
      end
    end

    context "when the player has not played any match days" do
      it "renders an empty history state" do
        player = create(:player, approval_status: "approved", active: true)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak meczów")
        expect(response.body).to include("Ten zawodnik nie rozegrał jeszcze meczu w wybranym sezonie.")
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
