require "rails_helper"

RSpec.describe "Votes" do
  describe "GET /votes/:token" do
    context "when the vote token exists" do
      it "renders the public vote form without private phone data" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        mvp_candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        def_candidate = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48333333333", approval_status: "approved", active: true)
        match_day = create(:match_day, played_on: Date.new(2026, 6, 5), status: "finished")
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

      it "does not include the voter in selectable players" do
        voter = create(:player, name: "Voter Full Name", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day, played_on: Date.new(2026, 6, 5), status: "finished")
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: candidate)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        get "/votes/#{vote_token.token}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).not_to include("Voter Full Name")
      end

      it "redirects used tokens to the thank you page" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        match_day = create(:match_day, played_on: Date.new(2026, 6, 5), status: "finished")
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token", used_at: Time.zone.parse("2026-06-05 21:30:00"))

        get "/votes/#{vote_token.token}"

        expect(response).to redirect_to("/votes/#{vote_token.token}/thank-you")
      end
    end

    context "when the vote token does not exist" do
      it "returns not found" do
        get "/votes/missing-token"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when a newer match day has finished" do
      it "returns not found for the previous match day token" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        match_day = create(:match_day, played_on: Date.new(2026, 6, 5), status: "finished")
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")
        create(:match_day, season: match_day.season, played_on: Date.new(2026, 6, 12), status: "finished")

        get "/votes/#{vote_token.token}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /votes/:token/thank-you" do
    context "when the vote token exists" do
      it "renders the public thank you page without private phone data" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        match_day = create(:match_day, played_on: Date.new(2026, 6, 5), status: "finished")
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        get "/votes/#{vote_token.token}/thank-you"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Dziekujemy za glos")
        expect(response.body).to include("Glos oddany przez")
        expect(response.body).to include("voter")
        expect(response.body).to include("2026-06-05")
        expect(response.body).to include("Twoj glos MVP i DEF zostal zapisany.")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the vote token does not exist" do
      it "returns not found" do
        get "/votes/missing-token/thank-you"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /votes/:token" do
    context "when the vote token and params are valid" do
      it "creates the vote and redirects to the thank you page" do
        season = create(:season, mvp_max_points: 4.0, def_max_points: 3.0, voting_bonus_cap: 5.0, expected_voters_count: 5)
        voter = create(:player, approval_status: "approved", active: true, global_performance_score: 0.0)
        mvp_candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true, global_performance_score: 0.0)
        def_candidate = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48333333333", approval_status: "approved", active: true, global_performance_score: 0.0)
        match_day = create(:match_day, season:, status: "finished")
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

        expect(response).to redirect_to("/votes/#{vote_token.token}/thank-you")
        expect(flash[:notice]).to eq("Glos zapisany")
        expect(vote_token.reload.match_day_vote).to have_attributes(
          mvp_player: mvp_candidate,
          def_player: def_candidate
        )
        expect(vote_token.used_at).to be_present
        expect(vote_token.match_day_vote.submitted_at).to be_present
        expect(PlayerSeasonStat.find_by!(player: mvp_candidate, season: season).attributes.slice("mvp_votes_count", "def_votes_count", "performance_score")).to eq(
          "mvp_votes_count" => 1,
          "def_votes_count" => 0,
          "performance_score" => BigDecimal("0.8")
        )
        expect(PlayerSeasonStat.find_by!(player: def_candidate, season: season).attributes.slice("mvp_votes_count", "def_votes_count", "performance_score")).to eq(
          "mvp_votes_count" => 0,
          "def_votes_count" => 1,
          "performance_score" => BigDecimal("0.6")
        )
        expect(PlayerRatingChange.find_by!(player: mvp_candidate, season: season, match_day: match_day, source_type: PlayerRatingChange::SOURCE_TYPE_VOTE).performance_delta).to eq(BigDecimal("0.8"))
        expect(PlayerRatingChange.find_by!(player: def_candidate, season: season, match_day: match_day, source_type: PlayerRatingChange::SOURCE_TYPE_VOTE).performance_delta).to eq(BigDecimal("0.6"))
      end

      it "allows the same non-voter to be selected for MVP and DEF" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        selected_player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day, status: "finished")
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: selected_player)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: selected_player.id,
            def_player_id: selected_player.id
          }
        }

        expect(response).to redirect_to("/votes/#{vote_token.token}/thank-you")
        expect(vote_token.reload.match_day_vote).to have_attributes(
          mvp_player: selected_player,
          def_player: selected_player
        )
        expect(vote_token.used_at).to be_present
      end

      it "does not update an already used token" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        original_mvp = create(:player, name: "Original MVP", nickname: "original-mvp", phone: "+48222222222", approval_status: "approved", active: true)
        original_def = create(:player, name: "Original DEF", nickname: "original-def", phone: "+48333333333", approval_status: "approved", active: true)
        new_choice = create(:player, name: "New Choice", nickname: "new-choice", phone: "+48444444444", approval_status: "approved", active: true)
        match_day = create(:match_day, status: "finished")
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: original_mvp)
        create(:match_day_player, match_day: match_day, player: original_def)
        create(:match_day_player, match_day: match_day, player: new_choice)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token", used_at: Time.zone.parse("2026-06-05 21:30:00"))
        MatchDayVote.create!(match_day_vote_token: vote_token, mvp_player: original_mvp, def_player: original_def)

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: new_choice.id,
            def_player_id: new_choice.id
          }
        }

        expect(response).to redirect_to("/votes/#{vote_token.token}/thank-you")
        expect(vote_token.reload.match_day_vote).to have_attributes(
          mvp_player: original_mvp,
          def_player: original_def
        )
        expect(vote_token.used_at).to eq(Time.zone.parse("2026-06-05 21:30:00"))
      end

      it "redirects a previously submitted link and rejects a second submission" do
        season = create(:season, mvp_max_points: 4.0, def_max_points: 3.0, voting_bonus_cap: 5.0, expected_voters_count: 5)
        voter = create(:player, name: "Voter", nickname: "voter", approval_status: "approved", active: true, global_performance_score: 0.0)
        original_mvp = create(:player, name: "Original MVP", nickname: "original-mvp", approval_status: "approved", active: true, global_performance_score: 0.0)
        original_def = create(:player, name: "Original DEF", nickname: "original-def", approval_status: "approved", active: true, global_performance_score: 0.0)
        new_choice = create(:player, name: "New Choice", nickname: "new-choice", approval_status: "approved", active: true, global_performance_score: 0.0)
        match_day = create(:match_day, season:, status: "finished")
        voter_match_day_player = create(:match_day_player, match_day:, player: voter)
        create(:match_day_player, match_day:, player: original_mvp)
        create(:match_day_player, match_day:, player: original_def)
        create(:match_day_player, match_day:, player: new_choice)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: original_mvp.id,
            def_player_id: original_def.id
          }
        }

        expect(response).to redirect_to("/votes/#{vote_token.token}/thank-you")
        expect(vote_token.reload).to be_used

        get "/votes/#{vote_token.token}"

        expect(response).to redirect_to("/votes/#{vote_token.token}/thank-you")

        expect do
          post "/votes/#{vote_token.token}", params: {
            match_day_vote: {
              mvp_player_id: new_choice.id,
              def_player_id: new_choice.id
            }
          }
        end.not_to change(MatchDayVote, :count)

        expect(response).to redirect_to("/votes/#{vote_token.token}/thank-you")
        expect(vote_token.reload.match_day_vote).to have_attributes(
          mvp_player: original_mvp,
          def_player: original_def
        )
      end

      it "returns not found for tokens superseded by a newer finished match day" do
        voter = create(:player, approval_status: "approved", active: true)
        candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day, status: "finished")
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: candidate)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")
        create(:match_day, season: match_day.season, played_on: Date.new(2026, 6, 12), status: "finished")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: candidate.id,
            def_player_id: candidate.id
          }
        }

        expect(response).to have_http_status(:not_found)
        expect(vote_token.reload.match_day_vote).to be_nil
        expect(vote_token.used_at).to be_nil
      end
    end

    context "when the vote params are invalid" do
      it "re-renders the form with errors" do
        voter = create(:player, approval_status: "approved", active: true)
        candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day, status: "finished")
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
        expect(vote_token.reload.used_at).to be_nil
      end

      it "rejects self-voting selections" do
        voter = create(:player, name: "Voter", nickname: "voter", phone: "+48111111111", approval_status: "approved", active: true)
        candidate = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day, status: "finished")
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
        expect(vote_token.used_at).to be_nil
      end

      it "rejects players outside the match day" do
        voter = create(:player, name: "Voter", nickname: "voter", approval_status: "approved", active: true)
        present_candidate = create(:player, name: "Present Candidate", nickname: "present", approval_status: "approved", active: true)
        outside_candidate = create(:player, name: "Outside Candidate", nickname: "outside", approval_status: "approved", active: true)
        match_day = create(:match_day, status: "finished")
        voter_match_day_player = create(:match_day_player, match_day:, player: voter)
        create(:match_day_player, match_day:, player: present_candidate)
        vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player, token: "vote-token")

        post "/votes/#{vote_token.token}", params: {
          match_day_vote: {
            mvp_player_id: outside_candidate.id,
            def_player_id: present_candidate.id
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Mvp player must belong to the match day")
        expect(vote_token.reload.match_day_vote).to be_nil
        expect(vote_token.used_at).to be_nil
      end
    end
  end
end
