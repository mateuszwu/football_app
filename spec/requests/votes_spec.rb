require "rails_helper"

RSpec.describe "Votes" do
  describe "GET /votes/:token" do
    context "when the vote token exists" do
      it "renders the public vote form without private phone data" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        mvp_candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        def_candidate = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48333333333", approval_status: "approved", active: true)
        match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: mvp_candidate)
        create(:match_day_player, match_day: match_day, player: def_candidate)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        get "/votes/#{vote_token.token}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("MVP i DEF")
        expect(response.body).to include("Glosuje:")
        expect(response.body).to include("voter")
        expect(response.body).to include("2026-06-05")
        expect(response.body).to include("Wybierz MVP")
        expect(response.body).to include("Wybierz DEF")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("Marek Kowalski")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("+48333333333")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the vote token does not exist" do
      it "returns not found" do
        get "/votes/missing-token"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /votes/:token" do
    context "when the vote token and params are valid" do
      it "creates the vote and redirects back to the form" do
        voter = create(:player, approval_status: "approved", active: true)
        mvp_candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        def_candidate = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48333333333", approval_status: "approved", active: true)
        match_day = create(:match_day)
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: mvp_candidate)
        create(:match_day_player, match_day: match_day, player: def_candidate)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: mvp_candidate.id,
            def_player_id: def_candidate.id
          }
        }

        expect(response).to redirect_to("/votes/#{vote_token.token}")
        expect(flash[:notice]).to eq("Glos zapisany")
        expect(vote_token.reload.match_day_vote).to have_attributes(
          mvp_player: mvp_candidate,
          def_player: def_candidate
        )
      end

      it "allows the same non-voter to be selected for MVP and DEF" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        selected_player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day)
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: selected_player)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: selected_player.id,
            def_player_id: selected_player.id
          }
        }

        expect(response).to redirect_to("/votes/#{vote_token.token}")
        expect(vote_token.reload.match_day_vote).to have_attributes(
          mvp_player: selected_player,
          def_player: selected_player
        )
      end
    end

    context "when the vote params are invalid" do
      it "re-renders the form with errors" do
        voter = create(:player, approval_status: "approved", active: true)
        candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day)
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: candidate)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: "",
            def_player_id: candidate.id
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Popraw bledy formularza:")
        expect(response.body).to include("Mvp player must exist")
      end

      it "rejects self-voting selections" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day)
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: candidate)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: voter.id,
            def_player_id: candidate.id
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Mvp player cannot be the voter")
        expect(vote_token.reload.match_day_vote).to be_nil
      end
    end
  end
end
