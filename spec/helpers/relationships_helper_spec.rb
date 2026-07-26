require "rails_helper"

RSpec.describe RelationshipsHelper do
  describe "#relationship_table_shared_header" do
    it "uses shared matches when match-level data exists" do
      summary = Relationships::DuoInsightsQuery::Summary.new(shared_matches_count: 1, shared_match_days_count: 1)
      insights = Relationships::DuoInsightsQuery::Result.new(summaries: [ summary ])

      expect(helper.relationship_table_shared_header(insights)).to eq("Wspólne mecze")
    end

    it "uses shared days when only match-day data exists" do
      summary = Relationships::DuoInsightsQuery::Summary.new(shared_matches_count: 0, shared_match_days_count: 2)
      insights = Relationships::DuoInsightsQuery::Result.new(summaries: [ summary ])

      expect(helper.relationship_table_shared_header(insights)).to eq("Wspólne dni")
    end
  end

  describe "#relationship_secondary_metrics" do
    it "returns win rate, shared matches, and split stats for offensive cards" do
      summary = Relationships::DuoInsightsQuery::Summary.new(
        shared_matches_count: 5,
        shared_match_days_count: 5,
        wins: 3,
        draws: 1,
        losses: 1,
        goals: 4,
        assists: 2
      )

      result = helper.relationship_secondary_metrics(summary, :offense_total)

      expect(result).to include("60% wygranych")
      expect(result).to include("5 wspólnych meczów")
      expect(result).to include("4 goli · 2 asyst")
    end
  end

  describe "#relationship_primary_metric" do
    it "uses mutual assists for direct offensive cards" do
      summary = Relationships::DuoInsightsQuery::Summary.new(mutual_assists: 3)

      result = helper.relationship_primary_metric(summary, :direct_offense_total)

      expect(result).to eq("3 asysty między sobą")
    end

    it "falls back to shared days when win rate is unavailable" do
      summary = Relationships::DuoInsightsQuery::Summary.new(
        shared_matches_count: 0,
        shared_match_days_count: 2
      )

      result = helper.relationship_primary_metric(summary, :win_rate)

      expect(result).to eq("2 wspólne dni grania")
    end
  end

  describe "#relationship_combination_label" do
    it "returns labels for scalable ranking tabs and falls back to duet" do
      expect(helper.relationship_combination_label("trios")).to eq("Trio")
      expect(helper.relationship_combination_label("unknown")).to eq("Duet")
    end
  end

  describe "#relationship_win_rate_class" do
    context "when the win rate is at least 50 percent" do
      it "returns the positive class" do
        expect(helper.relationship_win_rate_class(50)).to eq("relationship-win-rate relationship-win-rate--positive")
      end
    end

    context "when the win rate is below 50 percent" do
      it "returns the negative class" do
        expect(helper.relationship_win_rate_class(49)).to eq("relationship-win-rate relationship-win-rate--negative")
      end
    end

    context "when the win rate is unavailable" do
      it "returns the neutral base class" do
        expect(helper.relationship_win_rate_class(nil)).to eq("relationship-win-rate")
      end
    end
  end

  describe "#relationship_ranking_players_count" do
    it "counts unique players from visible ranking results" do
      adam = build_stubbed(:player)
      marek = build_stubbed(:player)
      first_result = Synergy::CombinationRankingQuery::Result.new(players: [ adam, marek ])
      second_result = Synergy::CombinationRankingQuery::Result.new(players: [ adam ])

      result = helper.relationship_ranking_players_count([ first_result, second_result ])

      expect(result).to eq(2)
    end
  end

  describe "#relationship_sorted_ranking" do
    it "sorts combinations by the selected column and recalculates ranks" do
      adam = build_stubbed(:player, name: "Adam Nowak")
      marek = build_stubbed(:player, name: "Marek Kowalski")
      cezary = build_stubbed(:player, name: "Cezary Lis")
      first_result = Synergy::CombinationRankingQuery::Result.new(
        players: [ adam, marek ],
        shared_matches_count: 3,
        wins: 2,
        draws: 0,
        losses: 1,
        goals: 4,
        assists: 1,
        mutual_assists: 1
      )
      second_result = Synergy::CombinationRankingQuery::Result.new(
        players: [ adam, cezary ],
        shared_matches_count: 7,
        wins: 4,
        draws: 1,
        losses: 2,
        goals: 2,
        assists: 0,
        mutual_assists: 0
      )

      result = helper.relationship_sorted_ranking(
        [ first_result, second_result ],
        sort_column: "matches",
        sort_direction: "asc"
      )

      expect(result.map(&:shared_matches_count)).to eq([ 3, 7 ])
      expect(result.map(&:rank)).to eq([ 1, 2 ])
    end
  end

  describe "#relationship_win_rate_label" do
    it "returns nil when the duo has no match-level record" do
      summary = Relationships::DuoInsightsQuery::Summary.new(
        shared_matches_count: 0,
        shared_match_days_count: 2
      )

      result = helper.relationship_win_rate_label(summary)

      expect(result).to be_nil
    end
  end
end
