require "rails_helper"

RSpec.describe PublicStats::CacheKey do
  describe ".season" do
    it "changes when tracked season data changes" do
      season = create(:season)
      initial_key = described_class.season(season)

      create(:match_day, season:)

      expect(described_class.season(season)).not_to eq(initial_key)
    end

    it "does not change for match days from another season" do
      season = create(:season)
      other_season = create(:season)
      initial_key = described_class.season(season)

      create(:match_day, season: other_season)

      expect(described_class.season(season)).to eq(initial_key)
    end
  end

  describe ".global" do
    it "changes when any tracked public data changes" do
      initial_key = described_class.global

      create(:player, approval_status: "approved")

      expect(described_class.global).not_to eq(initial_key)
    end

    it "reads the complete cache snapshot in one SQL query" do
      create(:player, approval_status: "approved")
      described_class.global

      query_count = count_sql_queries { described_class.global }

      expect(query_count).to eq(1)
    end
  end

  def count_sql_queries(&)
    count = 0
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA CACHE TRANSACTION])
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &)
    count
  end
end
