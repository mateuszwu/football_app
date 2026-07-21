require "rails_helper"

RSpec.describe Ratings::EffectiveTeamElo do
  describe ".call" do
    it "returns the average Elo when the rosters are equal" do
      season = create(:season, player_advantage_elo: 40.0)
      first_player = create(:player)
      second_player = create(:player)
      opponent_players = Array.new(2) { create(:player) }
      elo_map = (opponent_players + [ first_player, second_player ]).index_by(&:id).transform_values { 1000 }

      result = described_class.call(
        players: [ first_player, second_player ],
        opponent_players:,
        elo_map:,
        season:,
        all_roster_players_on_pitch: true
      )

      expect(result).to eq(1000.0)
    end

    it "adds the advantage for a larger team only when all players are on the pitch" do
      season = create(:season, player_advantage_elo: 40.0)
      players = Array.new(3) { create(:player) }
      opponent_players = Array.new(2) { create(:player) }
      elo_map = (players + opponent_players).index_by(&:id).transform_values { 1000 }

      result = described_class.call(
        players:,
        opponent_players:,
        elo_map:,
        season:,
        all_roster_players_on_pitch: true
      )

      expect(result).to eq(1040.0)
    end

    it "keeps a larger roster at its average when a substitute is rotating" do
      season = create(:season, player_advantage_elo: 40.0)
      players = Array.new(3) { create(:player) }
      opponent_players = Array.new(2) { create(:player) }
      elo_map = (players + opponent_players).index_by(&:id).transform_values { 1000 }

      result = described_class.call(
        players:,
        opponent_players:,
        elo_map:,
        season:,
        all_roster_players_on_pitch: false
      )

      expect(result).to eq(1000.0)
    end

    it "does not penalize the smaller team" do
      season = create(:season, player_advantage_elo: 40.0)
      player = create(:player)
      opponent_players = Array.new(2) { create(:player) }
      elo_map = (opponent_players + [ player ]).index_by(&:id).transform_values { 1000 }

      result = described_class.call(
        players: [ player ],
        opponent_players:,
        elo_map:,
        season:,
        all_roster_players_on_pitch: true
      )

      expect(result).to eq(1000.0)
    end

    it "returns zero when the team has no players" do
      season = create(:season, player_advantage_elo: 40.0)
      result = described_class.call(
        players: [],
        opponent_players: [ create(:player) ],
        elo_map: {},
        season:
      )

      expect(result).to eq(0.0)
    end
  end
end
