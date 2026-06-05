require "rails_helper"

RSpec.describe Players::BestDuoLeaderboardQuery do
  describe ".call" do
    context "when multiple player pairs have shared match days" do
      it "returns duos ranked by shared match days and player names" do
        adam = create(:player, name: "Adam")
        zed = create(:player, name: "Zed")
        beta = create(:player, name: "Beta")
        charlie = create(:player, name: "Charlie")
        marek = create(:player, name: "Marek")
        solo = create(:player, name: "Solo")
        first_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, played_on: Date.new(2026, 6, 12))
        third_match_day = create(:match_day, played_on: Date.new(2026, 6, 19))
        fourth_match_day = create(:match_day, played_on: Date.new(2026, 6, 26))
        fifth_match_day = create(:match_day, played_on: Date.new(2026, 7, 3))
        create(:match_day_player, player: adam, match_day: first_match_day)
        create(:match_day_player, player: zed, match_day: first_match_day)
        create(:match_day_player, player: adam, match_day: second_match_day)
        create(:match_day_player, player: zed, match_day: second_match_day)
        create(:match_day_player, player: marek, match_day: second_match_day)
        create(:match_day_player, player: beta, match_day: third_match_day)
        create(:match_day_player, player: charlie, match_day: third_match_day)
        create(:match_day_player, player: beta, match_day: fourth_match_day)
        create(:match_day_player, player: charlie, match_day: fourth_match_day)
        create(:match_day_player, player: solo, match_day: fifth_match_day)

        result = described_class.call

        expect(result.map { |duo| [ duo.player_one.name, duo.player_two.name, duo.shared_match_days_count ] }).to eq(
          [
            [ "Adam", "Zed", 2 ],
            [ "Beta", "Charlie", 2 ],
            [ "Adam", "Marek", 1 ],
            [ "Marek", "Zed", 1 ]
          ]
        )
      end
    end

    context "when no pair has played together" do
      it "returns an empty array" do
        first_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, played_on: Date.new(2026, 6, 12))
        create(:match_day_player, player: create(:player), match_day: first_match_day)
        create(:match_day_player, player: create(:player), match_day: second_match_day)

        result = described_class.call

        expect(result).to eq([])
      end
    end
  end
end
