module Rankings
  class CompetitionRanker
    RankedEntry = Struct.new(:entry, :rank, :value, keyword_init: true)

    def self.call(entries:, value_method:)
      new(entries:, value_method:).call
    end

    def initialize(entries:, value_method:)
      @entries = entries
      @value_method = value_method
    end

    def call
      previous_value = nil
      previous_rank = 0

      entries.each_with_index.map do |entry, index|
        value = value_for(entry)
        rank = value == previous_value ? previous_rank : index + 1
        previous_value = value
        previous_rank = rank

        RankedEntry.new(entry:, rank:, value:)
      end
    end

    private

    attr_reader :entries, :value_method

    def value_for(entry)
      return value_method.call(entry) if value_method.respond_to?(:call)

      entry.public_send(value_method) || 0
    end
  end
end
