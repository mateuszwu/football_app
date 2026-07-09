module Teams
  class UpdateMatchLineup
    def self.call(match:, teams_data:)
      new(match:, teams_data:).call
    end

    def initialize(match:, teams_data:)
      @match = match
      @teams_data = Array(teams_data).map { |team| team.is_a?(Hash) ? team.symbolize_keys : team.to_h.symbolize_keys }
    end

    def call
      return false unless match.not_started?
      return false unless valid_assignments?

      Team.transaction do
        new_teams = normalized_teams_data.map.with_index do |team_data, index|
          create_team(team_data:, index:)
        end

        match.update!(home_team: new_teams.first, away_team: new_teams.second)
        Team.where(id: existing_match_teams.map(&:id)).destroy_all
      end

      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :teams_data

    def valid_assignments?
      if normalized_teams_data.size < 2
        match.errors.add(:base, "At least two teams are required")
      end

      if overlapping_player_ids.any?
        match.errors.add(:base, "Player cannot be assigned to more than one lineup team")
      end

      if invalid_player_ids.any?
        match.errors.add(:base, "Lineup teams must use selected match day players only")
      end

      if unassigned_player_ids.any?
        match.errors.add(:base, "All selected match day players must be assigned before the match starts")
      end

      match.errors.none?
    end

    def normalized_teams_data
      @normalized_teams_data ||= teams_data.filter_map do |team_data|
        name = team_data[:name]
        player_ids = normalize_ids(team_data[:player_ids])
        next if name.blank? || player_ids.empty?

        {
          id: team_data[:id].presence&.to_i,
          name:,
          captain_id: normalize_captain_id(team_data[:captain_id], player_ids),
          player_ids:
        }
      end
    end

    def overlapping_player_ids
      assigned_ids = []
      overlaps = []

      normalized_teams_data.each do |team_data|
        overlaps.concat(assigned_ids & team_data[:player_ids])
        assigned_ids.concat(team_data[:player_ids])
      end

      overlaps.uniq
    end

    def invalid_player_ids
      assigned_player_ids - match.match_day.player_ids
    end

    def unassigned_player_ids
      match.match_day.player_ids - assigned_player_ids
    end

    def assigned_player_ids
      normalized_teams_data.flat_map { |team_data| team_data[:player_ids] }.uniq
    end

    def existing_match_teams
      @existing_match_teams ||= match.teams.order(:created_at, :id).to_a.presence || [ match.home_team, match.away_team ].compact.uniq
    end

    def existing_team_by_id(id)
      existing_match_teams.find { |team| team.id == id }
    end

    def create_team(team_data:, index:)
      existing_team = existing_team_by_id(team_data[:id])
      team_setup = existing_team&.team_setup || match.home_team.team_setup || match.match_day.team_setups.first_or_create!

      team = team_setup.teams.create!(
        match: match,
        name: team_data[:name],
        team_type: Team::TEAM_TYPE_MATCH,
        lineup_source: existing_team&.lineup_source || Team::LINEUP_SOURCE_MANUAL,
        source_team: existing_team&.source_team,
        position: index + 1,
        playing: index < 2
      )

      team_data[:player_ids].each_with_index do |player_id, player_index|
        player = Player.find(player_id)
        team.team_players.create!(player:, position: player_index + 1)
      end
      team.update!(captain_id: team_data[:captain_id]) if team_data[:captain_id].present?

      team
    end

    def normalize_ids(ids)
      Array(ids).reject(&:blank?).map(&:to_i).uniq
    end

    def normalize_captain_id(captain_id, player_ids)
      captain_id = captain_id.presence&.to_i

      player_ids.include?(captain_id) ? captain_id : nil
    end
  end
end
