require "rails_helper"

RSpec.describe "Players" do
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
      it "creates a pending player, writes the edit cookie, and redirects back to the form" do
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

        expect(response).to redirect_to("/players/new")
        expect(flash[:notice]).to eq("Zgloszenie zawodnika zostalo zapisane i czeka na akceptacje.")
        expect(player.name).to eq("Adam Nowak")
        expect(player.nickname).to eq("adam")
        expect(player.phone).to eq("+48111111111")
        expect(player.description).to eq("Solid defender")
        expect(player.role_code).to eq("DEF")
        expect(player.approval_status).to eq("pending")
        expect(player.active).to eq(true)
        expect(cookies[:pending_player_edit_token]).to be_present

        payload, = JWT.decode(
          cookies[:pending_player_edit_token],
          Rails.application.secret_key_base,
          true,
          algorithm: Players::GenerateEditToken::ALGORITHM
        )

        expect(payload["player_id"]).to eq(player.id)
        expect(payload["exp"]).to be_within(5).of(Players::GenerateEditToken::EXPIRATION.from_now.to_i)
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
        cookies[:pending_player_edit_token] = Players::GenerateEditToken.call(player: player)

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
        cookies[:pending_player_edit_token] = Players::GenerateEditToken.call(player: other_player)

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
  end

  describe "PATCH /players/:id" do
    context "when the cookie belongs to the same pending player" do
      it "updates the player submission" do
        player = create(:player, approval_status: "pending", active: true, name: "Old Name", nickname: "oldnick")
        cookies[:pending_player_edit_token] = Players::GenerateEditToken.call(player: player)

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
        cookies[:pending_player_edit_token] = "not-a-token"

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
      it "renders the public profile with match history and without private phone data" do
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
        older_match_day = create(:match_day, played_on: Date.new(2026, 5, 22), status: "finished", season: create(:season, name: "Spring 2026"))
        latest_match_day = create(:match_day, played_on: Date.new(2026, 5, 29), status: "ready", season: create(:season, name: "Summer 2026"))
        create(:match_day_player, player: player, match_day: older_match_day)
        create(:match_day_player, player: player, match_day: latest_match_day)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("adam")
        expect(response.body).to include("DEF")
        expect(response.body).to include("Solid defender")
        expect(response.body).to include("Historia meczow")
        expect(response.body).to include("2026-05-29")
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("ready")
        expect(response.body).to include("2026-05-22")
        expect(response.body).to include("Spring 2026")
        expect(response.body.index("2026-05-29")).to be < response.body.index("2026-05-22")
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
