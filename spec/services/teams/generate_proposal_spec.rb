require "rails_helper"

RSpec.describe Teams::GenerateProposal do
  describe ".call" do
    it "balances the requested number of teams by season elo" do
      season = create(:season)
      top_player = create(:player, name: "Top", nickname: "top", phone: "+48123000111")
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48123000112")
      third_player = create(:player, name: "Third", nickname: "third", phone: "+48123000113")
      fourth_player = create(:player, name: "Fourth", nickname: "fourth", phone: "+48123000114")
      fifth_player = create(:player, name: "Fifth", nickname: "fifth", phone: "+48123000115")
      create(:player_season_stat, season:, player: top_player, elo: 1200)
      create(:player_season_stat, season:, player: second_player, elo: 1100)
      create(:player_season_stat, season:, player: third_player, elo: 1000)
      create(:player_season_stat, season:, player: fourth_player, elo: 900)
      create(:player_season_stat, season:, player: fifth_player, elo: 800)

      result = described_class.call(
        players: [ fifth_player, fourth_player, second_player, top_player, third_player ],
        options: { season: season, team_count: 3 }
      )

      expect(result).to eq(
        [
          { name: "Team A", team_type: Team::TEAM_TYPE_BASELINE, player_ids: [ top_player.id ], elo_total: 1200 },
          { name: "Team B", team_type: Team::TEAM_TYPE_BASELINE, player_ids: [ second_player.id, fifth_player.id ], elo_total: 1900 },
          { name: "Team C", team_type: Team::TEAM_TYPE_BASELINE, player_ids: [ third_player.id, fourth_player.id ], elo_total: 1900 }
        ]
      )
    end

    it "distributes all players across the requested teams" do
      players = create_list(:player, 5)

      result = described_class.call(players: players, options: { team_count: 3 })

      expect(result.map { |team| team[:name] }).to eq([ "Team A", "Team B", "Team C" ])
      expect(result.sum { |team| team[:player_ids].length }).to eq(5)
    end
  end
end
