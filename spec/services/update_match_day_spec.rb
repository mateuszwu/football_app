require "rails_helper"

RSpec.describe UpdateMatchDay do
  describe ".call" do
    context "when params are valid" do
      it "updates the match day and replaces selected players" do
        season = create(:season)
        other_season = create(:season, name: "Season 2 Update", starts_on: Date.new(2026, 7, 1))
        original_player = create(:player, approval_status: "approved", active: true)
        new_player = create(:player, name: "New Player", nickname: "new", phone: "+48987654321", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5))
        original_match_day_player = create(:match_day_player, match_day:, player: original_player)
        original_match_day_player.create_match_day_vote_token!(token: "original-token", expires_at: 48.hours.from_now)
        params = {
          season_id: other_season.id,
          played_on: Date.new(2026, 6, 12),
          player_ids: [ new_player.id.to_s ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day.reload.season).to eq(other_season)
        expect(match_day.played_on).to eq(Date.new(2026, 6, 12))
        expect(match_day.players).to contain_exactly(new_player)
        expect(match_day.match_day_players.first.match_day_vote_token).to be_present
        expect(MatchDayVoteToken.find_by(token: "original-token")).to be_nil
      end

      it "replaces manual baseline teams" do
        season = create(:season)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5))
        team_setup = create(:team_setup, match_day: match_day)
        old_team = create(:team, team_setup: team_setup, name: "Team A", team_type: "baseline")
        create(:team_player, team: old_team, player: first_player)
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 12),
          player_ids: [ second_player.id.to_s, third_player.id.to_s ],
          teams_data: [
            { name: "Team A", player_ids: [ second_player.id.to_s ] },
            { name: "Team B", player_ids: [ third_player.id.to_s ] }
          ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day.reload.status).to eq("ready")
        expect(match_day.reload.teams.find_by!(name: "Team A").players).to contain_exactly(second_player)
        expect(match_day.teams.find_by!(name: "Team B").players).to contain_exactly(third_player)
        expect(match_day.match_day_players.map(&:match_day_vote_token)).to all(be_present)
      end

      it "moves the match day back to setup when team assignments become incomplete" do
        season = create(:season)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5), status: "ready")
        create(:match_day_player, match_day:, player: first_player)
        create(:match_day_player, match_day:, player: second_player)
        team_setup = create(:team_setup, match_day: match_day)
        team_a = create(:team, team_setup:, name: "Team A", team_type: "baseline")
        team_b = create(:team, team_setup:, name: "Team B", team_type: "baseline")
        create(:team_player, team: team_a, player: first_player)
        create(:team_player, team: team_b, player: second_player)
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 12),
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
        expect(match_day.reload.status).to eq("setup")
      end

      it "saves accepted auto-generated teams with reroll metadata" do
        season = create(:season)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5))
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 12),
          player_ids: [ first_player.id.to_s, second_player.id.to_s, third_player.id.to_s ],
          setup_method: TeamSetup::SETUP_METHOD_AUTO,
          algorithm_version: Teams::GenerateProposal::ALGORITHM_VERSION,
          reroll_count: 3,
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
        expect(match_day.reload.team_setups.first.setup_method).to eq(TeamSetup::SETUP_METHOD_AUTO)
        expect(match_day.team_setups.first.algorithm_version).to eq(Teams::GenerateProposal::ALGORITHM_VERSION)
        expect(match_day.team_setups.first.reroll_count).to eq(3)
        expect(match_day.teams.find_by!(name: "Team A").lineup_source).to eq(Team::LINEUP_SOURCE_AUTO)
        expect(match_day.teams.find_by!(name: "Team C").lineup_source).to eq(Team::LINEUP_SOURCE_AUTO)
      end
    end

    context "when params are invalid" do
      it "returns false and keeps the existing match day values" do
        season = create(:season)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5))
        params = { season_id: nil, played_on: nil, player_ids: [] }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(false)
        expect(match_day.reload.played_on).to eq(Date.new(2026, 6, 5))
        expect(match_day.errors[:season]).to include("must exist")
        expect(match_day.errors[:played_on]).to include("can't be blank")
      end
    end
  end
end
