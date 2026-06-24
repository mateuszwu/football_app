require "rails_helper"

RSpec.describe Rankings::CompetitionRanker do
  describe ".call" do
    it "uses competition ranking for tied values" do
      first = instance_double(PlayerSeasonStat, goals: 10)
      second = instance_double(PlayerSeasonStat, goals: 10)
      third = instance_double(PlayerSeasonStat, goals: 10)
      fourth = instance_double(PlayerSeasonStat, goals: 8)

      result = described_class.call(entries: [ first, second, third, fourth ], value_method: :goals)

      expect(result.map(&:entry)).to eq([ first, second, third, fourth ])
      expect(result.map(&:rank)).to eq([ 1, 1, 1, 4 ])
      expect(result.map(&:value)).to eq([ 10, 10, 10, 8 ])
    end

    it "keeps lower ranks offset by earlier ties" do
      first = instance_double(PlayerSeasonStat, elo: 1100)
      second = instance_double(PlayerSeasonStat, elo: 1050)
      third = instance_double(PlayerSeasonStat, elo: 1050)
      fourth = instance_double(PlayerSeasonStat, elo: 1000)

      result = described_class.call(entries: [ first, second, third, fourth ], value_method: :elo)

      expect(result.map(&:rank)).to eq([ 1, 2, 2, 4 ])
    end

    it "treats missing values as zero" do
      first = instance_double(PlayerSeasonStat, assists: nil)
      second = instance_double(PlayerSeasonStat, assists: 0)

      result = described_class.call(entries: [ first, second ], value_method: :assists)

      expect(result.map(&:rank)).to eq([ 1, 1 ])
      expect(result.map(&:value)).to eq([ 0, 0 ])
    end

    it "supports calculated values without changing competition ranking rules" do
      first = instance_double(PlayerSeasonStat, goals: 3, assists: 2)
      second = instance_double(PlayerSeasonStat, goals: 4, assists: 1)
      third = instance_double(PlayerSeasonStat, goals: 2, assists: 1)

      result = described_class.call(entries: [ first, second, third ], value_method: ->(entry) { entry.goals + entry.assists })

      expect(result.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.map(&:value)).to eq([ 5, 5, 3 ])
    end
  end
end
