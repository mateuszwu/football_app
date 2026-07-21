require "rails_helper"

RSpec.describe Ratings::CalculateTeamElo do
  describe ".call" do
    it "returns the average and effective Elo for equal teams" do
      season = create(:season, player_advantage_elo: 40.0)
      first_player = create(:player)
      second_player = create(:player)
      opponent_players = Array.new(2) { create(:player) }
      elo_map = {
        first_player.id => 1040,
        second_player.id => 960,
        **opponent_players.index_by(&:id).transform_values { 1000 }
      }

      result = described_class.call(
        players: [ first_player, second_player ],
        opponent_players:,
        elo_map:,
        season:,
        all_roster_players_on_pitch: true
      )

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1000.0)
    end

    it "does not add an advantage when a larger roster includes a substitute" do
      season = create(:season, player_advantage_elo: 40.0)
      players = Array.new(7) { create(:player) }
      opponent_players = Array.new(6) { create(:player) }
      elo_map = (players + opponent_players).index_by(&:id).transform_values { 1000 }

      result = described_class.call(
        players:,
        opponent_players:,
        elo_map:,
        season:,
        all_roster_players_on_pitch: false
      )

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1000.0)
    end

    it "adds the configured advantage for each extra player when everyone is on the pitch" do
      season = create(:season, player_advantage_elo: 40.0)
      players = Array.new(7) { create(:player) }
      opponent_players = Array.new(6) { create(:player) }
      elo_map = (players + opponent_players).index_by(&:id).transform_values { 1000 }

      result = described_class.call(
        players:,
        opponent_players:,
        elo_map:,
        season:,
        all_roster_players_on_pitch: true
      )

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1040.0)
    end

    it "does not penalize the smaller team below its average Elo" do
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

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1000.0)
    end
  end
end
