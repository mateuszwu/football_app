require "rails_helper"

RSpec.describe Players::RelationshipGraphQuery do
  describe ".call" do
    context "when approved active players share match days" do
      it "returns only public players, visible edges, and top teammates" do
        adam = create(:player, name: "Adam", nickname: "adam", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek", nickname: "marek", approval_status: "approved", active: true)
        zed = create(:player, name: "Zed", nickname: "zed", approval_status: "approved", active: true)
        pending_player = create(:player, name: "Pending", nickname: "pending", approval_status: "pending", active: true)
        inactive_player = create(:player, name: "Inactive", nickname: "inactive", approval_status: "approved", active: false)
        first_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, played_on: Date.new(2026, 6, 12))
        third_match_day = create(:match_day, played_on: Date.new(2026, 6, 19))
        create(:match_day_player, player: adam, match_day: first_match_day)
        create(:match_day_player, player: marek, match_day: first_match_day)
        create(:match_day_player, player: adam, match_day: second_match_day)
        create(:match_day_player, player: marek, match_day: second_match_day)
        create(:match_day_player, player: zed, match_day: second_match_day)
        create(:match_day_player, player: adam, match_day: third_match_day)
        create(:match_day_player, player: pending_player, match_day: third_match_day)
        create(:match_day_player, player: inactive_player, match_day: third_match_day)

        result = described_class.call

        expect(result.players.map(&:name)).to eq([ "Adam", "Marek", "Zed" ])
        expect(result.edges.map { |edge| [ edge.player_one.name, edge.player_two.name, edge.shared_match_days_count ] }).to eq(
          [
            [ "Adam", "Marek", 2 ],
            [ "Adam", "Zed", 1 ],
            [ "Marek", "Zed", 1 ]
          ]
        )
        expect(result.nodes.map { |node| [ node.player.name, node.top_teammates.map(&:name) ] }).to eq(
          [
            [ "Adam", [ "Marek" ] ],
            [ "Marek", [ "Adam" ] ],
            [ "Zed", [ "Adam", "Marek" ] ]
          ]
        )
      end
    end

    context "when there are no public shared relationships" do
      it "returns public players with no edges" do
        solo = create(:player, name: "Solo", nickname: "solo", approval_status: "approved", active: true)
        create(:match_day_player, player: solo, match_day: create(:match_day))

        result = described_class.call

        expect(result.players.map(&:name)).to eq([ "Solo" ])
        expect(result.edges).to eq([])
        expect(result.nodes.map { |node| [ node.player.name, node.top_teammates ] }).to eq([ [ "Solo", [] ] ])
      end
    end
  end
end
