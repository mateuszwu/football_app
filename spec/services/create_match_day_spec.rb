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
          team_a_player_ids: [ first_player.id.to_s ],
          team_b_player_ids: [ second_player.id.to_s ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(true)
        expect(match_day.teams.find_by!(name: "Team A").players).to contain_exactly(first_player)
        expect(match_day.teams.find_by!(name: "Team B").players).to contain_exactly(second_player)
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

      it "returns false when a player is assigned to both manual teams" do
        season = create(:season)
        player = create(:player, approval_status: "approved", active: true)
        match_day = MatchDay.new
        params = {
          season_id: season.id,
          played_on: Date.new(2026, 6, 5),
          player_ids: [ player.id.to_s ],
          team_a_player_ids: [ player.id.to_s ],
          team_b_player_ids: [ player.id.to_s ]
        }

        result = described_class.call(
          match_day: match_day,
          params: params,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be(false)
        expect(match_day.errors[:base]).to include("Player cannot be assigned to both manual teams")
      end
    end
  end
end
