module TeamSetups
  class ManualGeneratorAdapter < GeneratorAdapter
    TEAM_DEFINITIONS = {
      "Team A" => :team_a_player_ids,
      "Team B" => :team_b_player_ids,
      "Team 3" => :team_waiting_player_ids
    }.freeze

    def initialize(team_a_player_ids:, team_b_player_ids:, team_waiting_player_ids: [])
      @team_a_player_ids = normalize_ids(team_a_player_ids)
      @team_b_player_ids = normalize_ids(team_b_player_ids)
      @team_waiting_player_ids = normalize_ids(team_waiting_player_ids)
    end

    def call
      TEAM_DEFINITIONS.filter_map do |team_name, key|
        player_ids = player_ids_for(key)
        next if player_ids.empty?

        {
          name: team_name,
          team_type: "baseline",
          player_ids: player_ids
        }
      end
    end

    private

    attr_reader :team_a_player_ids, :team_b_player_ids, :team_waiting_player_ids

    def normalize_ids(ids)
      Array(ids).reject(&:blank?).map(&:to_i).uniq
    end

    def player_ids_for(key)
      case key
      when :team_a_player_ids
        team_a_player_ids
      when :team_b_player_ids
        team_b_player_ids
      when :team_waiting_player_ids
        team_waiting_player_ids
      else
        []
      end
    end
  end
end
