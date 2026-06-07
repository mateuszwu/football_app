module TeamSetups
  class SaveManualTeams
    def self.call(match_day:, selected_player_ids:, team_a_player_ids:, team_b_player_ids:, team_waiting_player_ids: [])
      new(
        match_day:,
        selected_player_ids:,
        team_a_player_ids:,
        team_b_player_ids:,
        team_waiting_player_ids:
      ).call
    end

    def initialize(match_day:, selected_player_ids:, team_a_player_ids:, team_b_player_ids:, team_waiting_player_ids:)
      @match_day = match_day
      @selected_player_ids = normalize_ids(selected_player_ids)
      @team_a_player_ids = normalize_ids(team_a_player_ids)
      @team_b_player_ids = normalize_ids(team_b_player_ids)
      @team_waiting_player_ids = normalize_ids(team_waiting_player_ids)
    end

    def call
      return false unless valid_assignments?

      if generated_teams.empty?
        match_day.team_setups.destroy_all
        return true
      end

      team_setup = match_day.team_setups.first_or_create!
      team_setup.teams.where(team_type: "baseline").destroy_all

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

    attr_reader :match_day, :selected_player_ids, :team_a_player_ids, :team_b_player_ids, :team_waiting_player_ids

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
      overlapping = []
      overlapping += (team_a_player_ids & team_b_player_ids)
      overlapping += (team_a_player_ids & team_waiting_player_ids)
      overlapping += (team_b_player_ids & team_waiting_player_ids)
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

      team = team_setup.teams.create!(name: team_name, team_type: team_type)
      player_ids.each do |player_id|
        team.team_players.create!(player_id:)
      end
    end

    def generated_teams
      @generated_teams ||= TeamSetups::ManualGeneratorAdapter.call(
        team_a_player_ids:,
        team_b_player_ids:,
        team_waiting_player_ids:
      )
    end

    def normalize_ids(ids)
      Array(ids).reject(&:blank?).map(&:to_i).uniq
    end
  end
end
