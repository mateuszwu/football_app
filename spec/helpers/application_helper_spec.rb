require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#ranked_entry_display_value" do
    it "returns the value calculated on the ranked entry" do
      entry = Rankings::CompetitionRanker::RankedEntry.new(entry: instance_double(PlayerSeasonStat), rank: 1, value: 10)

      result = helper.ranked_entry_display_value(entry)

      expect(result).to eq(10)
    end

    it "returns a fallback when the calculated value is blank" do
      entry = Rankings::CompetitionRanker::RankedEntry.new(entry: instance_double(PlayerSeasonStat), rank: 1, value: nil)

      result = helper.ranked_entry_display_value(entry)

      expect(result).to eq("-")
    end
  end
end
