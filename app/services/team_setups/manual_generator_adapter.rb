module TeamSetups
  class ManualGeneratorAdapter < GeneratorAdapter
    def initialize(teams_data:)
      @teams_data = teams_data || []
    end

    def call
      @teams_data.filter_map do |team_data|
        name = team_data[:name]
        player_ids = normalize_ids(team_data[:player_ids])
        next if name.blank? || player_ids.empty?

        {
          name: name,
          team_type: "baseline",
          player_ids: player_ids
        }
      end
    end

    private

    def normalize_ids(ids)
      Array(ids).reject(&:blank?).map(&:to_i).uniq
    end
  end
end
