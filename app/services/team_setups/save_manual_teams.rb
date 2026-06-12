module TeamSetups
  class SaveManualTeams
    def self.call(match_day:, selected_player_ids:, teams_data:)
      new(
        match_day:,
        selected_player_ids:,
        teams_data:
      ).call
    end

    def initialize(match_day:, selected_player_ids:, teams_data:)
      @match_day = match_day
      @selected_player_ids = normalize_ids(selected_player_ids)
      @teams_data = Array(teams_data).map { |d| d.is_a?(Hash) ? d.symbolize_keys : d }
    end

    def call
      return false unless valid_assignments?

      if generated_teams.empty?
        match_day.team_setups.destroy_all
        return true
      end

      team_setup = match_day.team_setups.first_or_create!
      team_setup.update!(
        setup_method: TeamSetup::SETUP_METHOD_MANUAL,
        accepted_at: Time.current
      )
      team_setup.teams.where(team_type: Team::TEAM_TYPE_BASELINE).destroy_all

      generated_teams.each do |team_definition|
        create_team(
          team_setup:,
          team_name: team_definition.fetch(:name),
          team_type: team_definition.fetch(:team_type),
          player_ids: team_definition.fetch(:player_ids)
        )
      end

      true
    end

    private

    attr_reader :match_day, :selected_player_ids, :teams_data

    def valid_assignments?
      if overlapping_player_ids.any?
        match_day.errors.add(:base, "Player cannot be assigned to more than one manual team")
      end

      if invalid_player_ids.any?
        match_day.errors.add(:base, "Manual teams must use selected match day players only")
      end

      match_day.errors.none?
    end

    def overlapping_player_ids
      all_assigned_ids = []
      overlapping = []

      generated_teams.each do |team|
        ids = team[:player_ids]
        overlapping += (all_assigned_ids & ids)
        all_assigned_ids += ids
      end

      overlapping.uniq
    end

    def invalid_player_ids
      manual_team_ids - selected_player_ids
    end

    def manual_team_ids
      generated_teams.flat_map { |team_definition| team_definition.fetch(:player_ids) }.uniq
    end

    def create_team(team_setup:, team_name:, team_type:, player_ids:)
      return if player_ids.empty?

      team = team_setup.teams.create!(
        name: team_name,
        team_type: team_type,
        lineup_source: Team::LINEUP_SOURCE_MANUAL
      )
      player_ids.each do |player_id|
        team.team_players.create!(player_id:)
      end
    end

    def generated_teams
      @generated_teams ||= TeamSetups::ManualGeneratorAdapter.call(
        teams_data: teams_data
      )
    end

    def normalize_ids(ids)
      Array(ids).reject(&:blank?).map(&:to_i).uniq
    end
  end
end
