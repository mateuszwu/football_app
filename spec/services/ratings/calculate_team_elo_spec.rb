require "rails_helper"

RSpec.describe Ratings::CalculateTeamElo do
  describe ".call" do
    it "returns the average and effective Elo with no size advantage for equal teams" do
      season = create(:season, player_advantage_elo: 40.0)
      first_player = create(:player)
      second_player = create(:player)
      opponent_player = create(:player)
      opponent_player_two = create(:player)
      elo_map = {
        first_player.id => 1040,
        second_player.id => 960,
        opponent_player.id => 1000,
        opponent_player_two.id => 1000
      }

      result = described_class.call(
        players: [ first_player, second_player ],
        opponent_players: [ opponent_player, opponent_player_two ],
        elo_map: elo_map,
        season: season
      )

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1000.0)
    end

    it "adds one season-sized advantage step for a 5v4 team" do
      season = create(:season, player_advantage_elo: 40.0)
      players = Array.new(5) { create(:player) }
      opponent_players = Array.new(4) { create(:player) }
      elo_map = (players + opponent_players).index_by(&:id).transform_values { 1000 }

      result = described_class.call(players: players.first(5), opponent_players: opponent_players, elo_map: elo_map, season: season)

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1040.0)
    end

    it "adds two season-sized advantage steps for a 6v4 team" do
      season = create(:season, player_advantage_elo: 40.0)
      players = Array.new(6) { create(:player) }
      opponent_players = Array.new(4) { create(:player) }
      elo_map = (players + opponent_players).index_by(&:id).transform_values { 1000 }

      result = described_class.call(players: players.first(6), opponent_players: opponent_players, elo_map: elo_map, season: season)

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1080.0)
    end

    it "uses the season player advantage value" do
      season = create(:season, player_advantage_elo: 25.0)
      players = Array.new(3) { create(:player) }
      opponent_players = Array.new(2) { create(:player) }
      elo_map = (players + opponent_players).index_by(&:id).transform_values { 1000 }

      result = described_class.call(players: players.first(3), opponent_players: opponent_players, elo_map: elo_map, season: season)

      expect(result.effective_elo).to eq(1025.0)
    end

    it "does not penalize the smaller team below its average elo" do
      season = create(:season, player_advantage_elo: 40.0)
      player = create(:player)
      opponent_players = Array.new(2) { create(:player) }
      elo_map = {
        player.id => 1000,
        opponent_players.first.id => 1000,
        opponent_players.second.id => 1000
      }

      result = described_class.call(players: [ player ], opponent_players: opponent_players, elo_map: elo_map, season: season)

      expect(result.average_elo).to eq(1000.0)
      expect(result.effective_elo).to eq(1000.0)
    end
  end
end
