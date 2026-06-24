require "rails_helper"

RSpec.describe LeaderboardsHelper do
  describe "#leaderboard_ranked_entries" do
    it "returns an empty list when leaderboards are missing" do
      expect(helper.leaderboard_ranked_entries(nil, "elo")).to eq([])
    end
  end

  describe "#leaderboard_summary_cards" do
    it "returns empty summary cards when leaderboards are missing" do
      result = helper.leaderboard_summary_cards(nil)

      expect(result.size).to eq(5)
      expect(result.map { |card| card.fetch(:player_stat) }).to all(be_nil)
      expect(result.map { |card| card.fetch(:value) }).to all(be_nil)
    end
  end

  describe "#leaderboard_cell_value" do
    it "formats every supported table column" do
      player = build_stubbed(:player, name: "Adam Nowak", role_code: "ATT")
      player_stat_class = Struct.new(
        :player,
        :matches_played_count,
        :elo,
        :goals,
        :assists,
        :mvp_votes_count,
        :def_votes_count,
        :last_elo_delta_value,
        :goals_per_match_value,
        :assists_per_match_value,
        :goals_assists_per_match_value,
        :wins_count,
        :draws_count,
        :losses_count,
        :win_rate_value,
        :goal_difference_value,
        keyword_init: true
      )
      player_stat = player_stat_class.new(
        player:,
        matches_played_count: 4,
        elo: 1040,
        goals: 5,
        assists: 3,
        mvp_votes_count: 2,
        def_votes_count: 1,
        last_elo_delta_value: 18,
        goals_per_match_value: BigDecimal("1.25"),
        assists_per_match_value: BigDecimal("0.75"),
        goals_assists_per_match_value: BigDecimal("2.0"),
        wins_count: 3,
        draws_count: 1,
        losses_count: 0,
        win_rate_value: BigDecimal("75.0"),
        goal_difference_value: 8
      )
      ranked_entry = Rankings::CompetitionRanker::RankedEntry.new(entry: player_stat, rank: 1, value: 8)

      expect(helper.leaderboard_cell_value(player_stat, :position, ranked_entry)).to eq(1)
      expect(helper.leaderboard_cell_value(player_stat, :player, ranked_entry)).to eq("Adam Nowak")
      expect(helper.leaderboard_cell_value(player_stat, :role, ranked_entry)).to eq("Napastnik")
      expect(helper.leaderboard_cell_value(player_stat, :matches, ranked_entry)).to eq(4)
      expect(helper.leaderboard_cell_value(player_stat, :elo, ranked_entry)).to eq(1040)
      expect(helper.leaderboard_cell_value(player_stat, :last_change, ranked_entry)).to include("+18")
      expect(helper.leaderboard_cell_value(player_stat, :last_change, ranked_entry)).to include("lucide-trending-up")
      expect(helper.leaderboard_cell_value(player_stat, :goals, ranked_entry)).to eq(5)
      expect(helper.leaderboard_cell_value(player_stat, :goals_per_match, ranked_entry)).to eq("1.25")
      expect(helper.leaderboard_cell_value(player_stat, :assists, ranked_entry)).to eq(3)
      expect(helper.leaderboard_cell_value(player_stat, :assists_per_match, ranked_entry)).to eq("0.75")
      expect(helper.leaderboard_cell_value(player_stat, :goals_assists, ranked_entry)).to eq(8)
      expect(helper.leaderboard_cell_value(player_stat, :goals_assists_per_match, ranked_entry)).to eq("2")
      expect(helper.leaderboard_cell_value(player_stat, :mvp_votes, ranked_entry)).to eq(2)
      expect(helper.leaderboard_cell_value(player_stat, :def_votes, ranked_entry)).to eq(1)
      expect(helper.leaderboard_cell_value(player_stat, :wins, ranked_entry)).to eq(3)
      expect(helper.leaderboard_cell_value(player_stat, :draws, ranked_entry)).to eq(1)
      expect(helper.leaderboard_cell_value(player_stat, :losses, ranked_entry)).to eq(0)
      expect(helper.leaderboard_cell_value(player_stat, :win_rate, ranked_entry)).to eq("75%")
      expect(helper.leaderboard_cell_value(player_stat, :goal_difference, ranked_entry)).to eq("+8")
    end

    it "shows a fallback for missing ELO values" do
      player = build_stubbed(:player)
      player_stat = Struct.new(:player, :elo, keyword_init: true).new(player:, elo: nil)
      ranked_entry = Rankings::CompetitionRanker::RankedEntry.new(entry: player_stat, rank: 1, value: nil)

      expect(helper.leaderboard_cell_value(player_stat, :elo, ranked_entry)).to eq("-")
    end

    it "shows fallbacks when per-match and record values have no matches" do
      player = build_stubbed(:player)
      player_stat = Struct.new(
        :player,
        :matches_played_count,
        :goals_per_match_value,
        :win_rate_value,
        :goal_difference_value,
        keyword_init: true
      ).new(player:, matches_played_count: 0, goals_per_match_value: 0, win_rate_value: 0, goal_difference_value: 0)
      ranked_entry = Rankings::CompetitionRanker::RankedEntry.new(entry: player_stat, rank: 1, value: 0)

      expect(helper.leaderboard_cell_value(player_stat, :goals_per_match, ranked_entry)).to eq("—")
      expect(helper.leaderboard_cell_value(player_stat, :win_rate, ranked_entry)).to eq("—")
      expect(helper.leaderboard_cell_value(player_stat, :goal_difference, ranked_entry)).to eq("0")
    end

    it "formats negative ELO deltas" do
      html = helper.leaderboard_delta_tag(-7)

      expect(html).to include("-7")
      expect(html).to include("leaderboards-delta--negative")
      expect(html).to include("lucide-trending-down")
    end

    it "does not render trend icons for empty ELO deltas" do
      html = helper.leaderboard_delta_tag(0)

      expect(html).to include("leaderboards-delta--muted")
      expect(html).not_to include("lucide-trending")
    end

    it "returns nil for unsupported columns" do
      player = build_stubbed(:player)
      player_stat = Struct.new(:player, keyword_init: true).new(player:)
      ranked_entry = Rankings::CompetitionRanker::RankedEntry.new(entry: player_stat, rank: 1, value: nil)

      expect(helper.leaderboard_cell_value(player_stat, :unknown, ranked_entry)).to be_nil
    end
  end

  describe "#leaderboard_player_initials" do
    it "returns two uppercase initials" do
      player = build_stubbed(:player, name: "Adam Nowak")

      expect(helper.leaderboard_player_initials(player)).to eq("AN")
    end
  end

  describe "#leaderboard_rank_badge" do
    it "renders medal colors for podium ranks" do
      gold = helper.leaderboard_rank_badge(1)
      silver = helper.leaderboard_rank_badge(2)
      bronze = helper.leaderboard_rank_badge(3)

      expect(gold).to include("leaderboards-rank--gold")
      expect(gold).to include("leaderboards-rank__medal")
      expect(gold).to include("lucide-medal")
      expect(silver).to include("leaderboards-rank--silver")
      expect(bronze).to include("leaderboards-rank--bronze")
    end

    it "keeps regular styling for non-podium ranks" do
      html = helper.leaderboard_rank_badge(6)

      expect(html).to include("leaderboards-rank")
      expect(html).not_to include("leaderboards-rank--medal")
      expect(html).not_to include("leaderboards-rank__medal")
    end
  end
end
