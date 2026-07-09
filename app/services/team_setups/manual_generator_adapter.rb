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

        team_definition = {
          name: name,
          team_type: "baseline",
          player_ids: player_ids
        }
        captain_id = normalize_captain_id(team_data[:captain_id], player_ids)
        team_definition[:captain_id] = captain_id if captain_id.present?
        team_definition
      end
    end

    private

    def normalize_ids(ids)
      Array(ids).reject(&:blank?).map(&:to_i).uniq
    end

    def normalize_captain_id(captain_id, player_ids)
      normalized_captain_id = captain_id.presence&.to_i

      player_ids.include?(normalized_captain_id) ? normalized_captain_id : nil
    end
  end
end
