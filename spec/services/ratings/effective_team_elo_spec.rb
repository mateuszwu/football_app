require "rails_helper"

RSpec.describe Ratings::EffectiveTeamElo do
  describe ".call" do
    context "when the team has players with Elo ratings" do
      it "returns the effective Elo across the team" do
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

        expect(result).to eq(1000.0)
      end
    end

    context "when the team has one extra player" do
      it "adds a 40 Elo advantage" do
        season = create(:season, player_advantage_elo: 40.0)
        first_player = create(:player)
        second_player = create(:player)
        extra_player = create(:player)
        opponent_player = create(:player)
        opponent_player_two = create(:player)
        elo_map = {
          first_player.id => 1000,
          second_player.id => 1000,
          extra_player.id => 1000,
          opponent_player.id => 1000,
          opponent_player_two.id => 1000
        }

        result = described_class.call(
          players: [ first_player, second_player, extra_player ],
          opponent_players: [ opponent_player, opponent_player_two ],
          elo_map: elo_map,
          season: season
        )

        expect(result).to eq(1040.0)
      end
    end

    context "when the team has one fewer player" do
      it "keeps the smaller team at its average Elo" do
        season = create(:season, player_advantage_elo: 40.0)
        player = create(:player)
        opponent_player = create(:player)
        opponent_player_two = create(:player)
        elo_map = {
          player.id => 1000,
          opponent_player.id => 1000,
          opponent_player_two.id => 1000
        }

        result = described_class.call(players: [ player ], opponent_players: [ opponent_player, opponent_player_two ], elo_map: elo_map, season: season)

        expect(result).to eq(1000.0)
      end
    end

    context "when the team has no players" do
      it "returns zero" do
        result = described_class.call(players: [], opponent_players: [], elo_map: {}, season: create(:season))

        expect(result).to eq(0.0)
      end
    end
  end
end
