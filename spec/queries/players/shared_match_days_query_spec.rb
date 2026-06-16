require "rails_helper"

RSpec.describe Players::SharedMatchDaysQuery do
  describe ".call" do
    context "when the player has shared match days with other players" do
      it "returns other players ordered by shared match days" do
        player = create(:player, name: "Main Player")
        most_frequent_teammate = create(:player, name: "Adam")
        tied_teammate = create(:player, name: "Zed")
        occasional_teammate = create(:player, name: "Marek")
        unrelated_player = create(:player, name: "Outside")
        first_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, played_on: Date.new(2026, 6, 12))
        third_match_day = create(:match_day, played_on: Date.new(2026, 6, 19))
        unrelated_match_day = create(:match_day, played_on: Date.new(2026, 6, 26))
        create(:match_day_player, player: player, match_day: first_match_day)
        create(:match_day_player, player: player, match_day: second_match_day)
        create(:match_day_player, player: most_frequent_teammate, match_day: first_match_day)
        create(:match_day_player, player: most_frequent_teammate, match_day: second_match_day)
        create(:match_day_player, player: tied_teammate, match_day: first_match_day)
        create(:match_day_player, player: tied_teammate, match_day: third_match_day)
        create(:match_day_player, player: occasional_teammate, match_day: second_match_day)
        create(:match_day_player, player: unrelated_player, match_day: unrelated_match_day)

        result = described_class.call(player: player)

        expect(result.map(&:name)).to eq([ "Adam", "Marek", "Zed" ])
        expect(result.map(&:shared_match_days_count)).to eq([ 2, 1, 1 ])
      end
    end

    context "when the player has no shared match days" do
      it "returns an empty relation" do
        player = create(:player)
        create(:match_day_player, player: player, match_day: create(:match_day))
        create(:match_day_player, player: create(:player), match_day: create(:match_day, played_on: Date.new(2026, 6, 12)))

        result = described_class.call(player: player)

        expect(result).to be_empty
      end
    end

    context "when a season filter is provided" do
      it "limits shared match days to that season" do
        season = create(:season, name: "Summer 2026")
        other_season = create(:season, name: "Spring 2026", starts_on: Date.new(2026, 3, 1))
        player = create(:player, name: "Main Player")
        summer_teammate = create(:player, name: "Adam")
        spring_teammate = create(:player, name: "Marek")
        summer_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5))
        spring_match_day = create(:match_day, season: other_season, played_on: Date.new(2026, 4, 5))
        create(:match_day_player, player:, match_day: summer_match_day)
        create(:match_day_player, player:, match_day: spring_match_day)
        create(:match_day_player, player: summer_teammate, match_day: summer_match_day)
        create(:match_day_player, player: spring_teammate, match_day: spring_match_day)

        result = described_class.call(player:, season:)

        expect(result.map(&:name)).to eq([ "Adam" ])
      end
    end
  end
end
