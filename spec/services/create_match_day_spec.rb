require "rails_helper"

RSpec.describe CreateMatchDay do
  describe ".call" do
    context "when params are valid" do
      it "creates the match day and assigns approved active players only" do
        season = create(:season)
        approved_player = create(:player, approval_status: "approved", active: true)
        pending_player = create(:player, name: "Pending", nickname: "pending", phone: "+48999999999", approval_status: "pending", active: true)
        match_day = MatchDay.new
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 5),
          player_ids: [ approved_player.id.to_s, pending_player.id.to_s ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day).to be_persisted
        expect(match_day.season).to eq(season)
        expect(match_day.played_on).to eq(Date.new(2026, 6, 5))
        expect(match_day.players).to contain_exactly(approved_player)
        expect(match_day.match_day_players.first.match_day_vote_token).to be_present
        expect(season.reload.pair_stats_generated_at).to be_present
      end

      it "creates manual baseline teams when team assignments are provided" do
        season = create(:season)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        match_day = MatchDay.new
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 5),
          player_ids: [ first_player.id.to_s, second_player.id.to_s ],
          teams_data: [
            { name: "Team A", player_ids: [ first_player.id.to_s ] },
            { name: "Team B", player_ids: [ second_player.id.to_s ] }
          ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day.status).to eq("ready")
        expect(match_day.teams.find_by!(name: "Team A").players).to contain_exactly(first_player)
        expect(match_day.teams.find_by!(name: "Team B").players).to contain_exactly(second_player)
        expect(match_day.match_day_players.map(&:match_day_vote_token)).to all(be_present)
        expect(match_day.teams.find_by!(name: "Team A")).to be_playing
        expect(match_day.teams.find_by!(name: "Team B")).to be_playing
      end

      it "creates an optional waiting baseline team as non-playing" do
        season = create(:season)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997", approval_status: "approved", active: true)
        match_day = MatchDay.new
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 5),
          player_ids: [ first_player.id.to_s, second_player.id.to_s, third_player.id.to_s ],
          teams_data: [
            { name: "Team A", player_ids: [ first_player.id.to_s ] },
            { name: "Team B", player_ids: [ second_player.id.to_s ] },
            { name: "Waiting", player_ids: [ third_player.id.to_s ] }
          ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day.teams.find_by!(name: "Team A")).to be_playing
        expect(match_day.teams.find_by!(name: "Team B")).to be_playing
        expect(match_day.teams.find_by!(name: "Waiting")).not_to be_playing
      end

      it "saves accepted auto-generated baseline teams with reroll metadata" do
        season = create(:season)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997", approval_status: "approved", active: true)
        match_day = MatchDay.new
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 5),
          player_ids: [ first_player.id.to_s, second_player.id.to_s, third_player.id.to_s ],
          setup_method: TeamSetup::SETUP_METHOD_AUTO,
          algorithm_version: Teams::GenerateProposal::ALGORITHM_VERSION,
          reroll_count: 2,
          teams_data: [
            { name: "Team A", player_ids: [ first_player.id.to_s ] },
            { name: "Team B", player_ids: [ second_player.id.to_s ] },
            { name: "Team C", player_ids: [ third_player.id.to_s ] }
          ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day.team_setups.first.setup_method).to eq(TeamSetup::SETUP_METHOD_AUTO)
        expect(match_day.team_setups.first.algorithm_version).to eq(Teams::GenerateProposal::ALGORITHM_VERSION)
        expect(match_day.team_setups.first.reroll_count).to eq(2)
        expect(match_day.teams.find_by!(name: "Team A").lineup_source).to eq(Team::LINEUP_SOURCE_AUTO)
        expect(match_day.teams.find_by!(name: "Team B").lineup_source).to eq(Team::LINEUP_SOURCE_AUTO)
        expect(match_day.teams.find_by!(name: "Team C").lineup_source).to eq(Team::LINEUP_SOURCE_AUTO)
      end

      it "keeps the match day in setup when selected players are not fully assigned" do
        season = create(:season)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        match_day = MatchDay.new
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 5),
          player_ids: [ first_player.id.to_s, second_player.id.to_s ],
          teams_data: [
            { name: "Team A", player_ids: [ first_player.id.to_s ] },
            { name: "Team B", player_ids: [] }
          ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day.status).to eq("setup")
      end
    end

    context "when params are invalid" do
      it "returns false and leaves validation errors on the match day" do
        match_day = MatchDay.new
        params = { season_id: nil, played_on: nil, player_ids: [] }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(false)
        expect(match_day.errors[:season]).to include("must exist")
        expect(match_day.errors[:played_on]).to include("can't be blank")
      end

      it "returns false when a player is assigned to more than one team" do
        season = create(:season)
        player = create(:player, approval_status: "approved", active: true)
        match_day = MatchDay.new
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 5),
          player_ids: [ player.id.to_s ],
          teams_data: [
            { name: "Team A", player_ids: [ player.id.to_s ] },
            { name: "Team B", player_ids: [ player.id.to_s ] }
          ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(false)
        expect(match_day.errors[:base]).to include("Player cannot be assigned to more than one manual team")
      end
    end
  end
end
