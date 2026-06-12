require "rails_helper"

RSpec.describe Teams::GenerateFingerprint do
  describe ".call" do
    it "returns the same fingerprint regardless of player order" do
      first_team = create(:team)
      second_team = create(:team)
      player_one = create(:player)
      player_two = create(:player, nickname: "player-two", phone: "+48123000999")
      player_three = create(:player, nickname: "player-three", phone: "+48123000998")

      create(:team_player, team: first_team, player: player_three)
      create(:team_player, team: first_team, player: player_one)
      create(:team_player, team: first_team, player: player_two)

      create(:team_player, team: second_team, player: player_two)
      create(:team_player, team: second_team, player: player_three)
      create(:team_player, team: second_team, player: player_one)

      first_fingerprint = described_class.call(team: first_team)
      second_fingerprint = described_class.call(team: second_team)

      expect(first_fingerprint).to eq(second_fingerprint)
      expect(first_fingerprint).to eq([ player_one.id, player_two.id, player_three.id ].sort.join("-"))
    end

    it "returns a different fingerprint for different players" do
      first_team = create(:team)
      second_team = create(:team)
      shared_player = create(:player)
      first_only_player = create(:player, nickname: "first-only", phone: "+48123000997")
      second_only_player = create(:player, nickname: "second-only", phone: "+48123000996")

      create(:team_player, team: first_team, player: shared_player)
      create(:team_player, team: first_team, player: first_only_player)

      create(:team_player, team: second_team, player: shared_player)
      create(:team_player, team: second_team, player: second_only_player)

      first_fingerprint = described_class.call(team: first_team)
      second_fingerprint = described_class.call(team: second_team)

      expect(first_fingerprint).not_to eq(second_fingerprint)
    end
  end
end
