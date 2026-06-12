require "rails_helper"

RSpec.describe Teams::GenerateProposal do
  describe ".call" do
    it "balances the first two teams by season elo" do
      season = create(:season)
      top_player = create(:player, name: "Top", nickname: "top", phone: "+48123000111")
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48123000112")
      third_player = create(:player, name: "Third", nickname: "third", phone: "+48123000113")
      fourth_player = create(:player, name: "Fourth", nickname: "fourth", phone: "+48123000114")
      create(:player_season_stat, season:, player: top_player, elo: 1200)
      create(:player_season_stat, season:, player: second_player, elo: 1100)
      create(:player_season_stat, season:, player: third_player, elo: 1000)
      create(:player_season_stat, season:, player: fourth_player, elo: 900)

      result = described_class.call(
        players: [ fourth_player, second_player, top_player, third_player ],
        options: { season: season }
      )

      expect(result).to eq(
        [
          { name: "Team A", team_type: Team::TEAM_TYPE_BASELINE, player_ids: [ top_player.id, fourth_player.id ], elo_total: 2100 },
          { name: "Team B", team_type: Team::TEAM_TYPE_BASELINE, player_ids: [ second_player.id, third_player.id ], elo_total: 2100 }
        ]
      )
    end

    it "creates a waiting team for an odd number of players" do
      players = create_list(:player, 3)

      result = described_class.call(players: players, options: {})

      expect(result.map { |team| team[:name] }).to eq([ "Team A", "Team B", "Waiting" ])
      expect(result.last[:player_ids].length).to eq(1)
      expect(result.sum { |team| team[:player_ids].length }).to eq(3)
    end
  end
end
