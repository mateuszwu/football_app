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

  describe "#relationship_player_avatars" do
    it "renders player initials without a size modifier by default" do
      player = build_stubbed(:player, name: "Adam Demo")

      result = helper.relationship_player_avatars([ player ])

      expect(result).to include("AD")
      expect(result).to include("href=\"#{player_path(player)}\"")
      expect(result).to include("data-turbo-frame=\"_top\"")
      expect(result).to include("title=\"Adam Demo\"")
      expect(result).to include("aria-label=\"Adam Demo\"")
      expect(result).to include("relationship-avatar__tooltip")
      expect(result).not_to include("relationship-avatar--")
    end
  end

  describe "#relationship_player_names" do
    it "renders profile links that escape the relationships turbo frame" do
      player = build_stubbed(:player, name: "Adam Demo")

      result = helper.relationship_player_names([ player ])

      expect(result).to include("Adam Demo")
      expect(result).to include("href=\"#{player_path(player)}\"")
      expect(result).to include("data-turbo-frame=\"_top\"")
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

  describe "#relationship_graph_layout" do
    it "centers a single player in the graph" do
      player = build_stubbed(:player)

      result = helper.relationship_graph_layout(players: [ player ], edges: [], width: 600, height: 400)

      expect(result.nodes.first.x).to eq(300)
      expect(result.nodes.first.y).to eq(200)
    end

    it "uses the minimum graph stroke width for a single-strength connection" do
      player_one = build_stubbed(:player)
      player_two = build_stubbed(:player)
      edge = Players::BestDuoLeaderboardQuery::Duo.new(
        player_one:,
        player_two:,
        shared_match_days_count: 1
      )

      result = helper.relationship_graph_layout(players: [ player_one, player_two ], edges: [ edge ])

      expect(result.edges.first.stroke_width).to eq(3.0)
    end
  end
end
