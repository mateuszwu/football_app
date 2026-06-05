require "rails_helper"

RSpec.describe Players::BestTeammatesQuery do
  describe ".call" do
    context "when one teammate has the highest shared match count" do
      it "returns the top teammate only" do
        player = create(:player, name: "Main Player")
        best_teammate = create(:player, name: "Adam")
        other_teammate = create(:player, name: "Zed")
        first_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, played_on: Date.new(2026, 6, 12))
        third_match_day = create(:match_day, played_on: Date.new(2026, 6, 19))
        create(:match_day_player, player: player, match_day: first_match_day)
        create(:match_day_player, player: player, match_day: second_match_day)
        create(:match_day_player, player: best_teammate, match_day: first_match_day)
        create(:match_day_player, player: best_teammate, match_day: second_match_day)
        create(:match_day_player, player: other_teammate, match_day: third_match_day)
        create(:match_day_player, player: player, match_day: third_match_day)

        result = described_class.call(player: player)

        expect(result.map(&:name)).to eq([ "Adam" ])
        expect(result.map(&:shared_match_days_count)).to eq([ 2 ])
      end
    end

    context "when multiple teammates tie for the highest shared match count" do
      it "returns all top teammates ordered by name" do
        player = create(:player, name: "Main Player")
        adam = create(:player, name: "Adam")
        marek = create(:player, name: "Marek")
        zed = create(:player, name: "Zed")
        first_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, played_on: Date.new(2026, 6, 12))
        third_match_day = create(:match_day, played_on: Date.new(2026, 6, 19))
        create(:match_day_player, player: player, match_day: first_match_day)
        create(:match_day_player, player: player, match_day: second_match_day)
        create(:match_day_player, player: adam, match_day: first_match_day)
        create(:match_day_player, player: adam, match_day: second_match_day)
        create(:match_day_player, player: marek, match_day: first_match_day)
        create(:match_day_player, player: marek, match_day: second_match_day)
        create(:match_day_player, player: zed, match_day: third_match_day)
        create(:match_day_player, player: player, match_day: third_match_day)

        result = described_class.call(player: player)

        expect(result.map(&:name)).to eq([ "Adam", "Marek" ])
        expect(result.map(&:shared_match_days_count)).to eq([ 2, 2 ])
      end
    end

    context "when the player has no teammates" do
      it "returns an empty array" do
        player = create(:player)
        create(:match_day_player, player: player, match_day: create(:match_day))

        result = described_class.call(player: player)

        expect(result).to eq([])
      end
    end
  end
end
