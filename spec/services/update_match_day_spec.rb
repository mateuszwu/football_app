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
        create(:match_day_player, match_day:, player: original_player)
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
