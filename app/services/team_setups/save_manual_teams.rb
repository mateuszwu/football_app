module TeamSetups
  class SaveManualTeams
    TEAM_DEFINITIONS = {
      "Team A" => :team_a_player_ids,
      "Team B" => :team_b_player_ids
    }.freeze

    def self.call(match_day:, selected_player_ids:, team_a_player_ids:, team_b_player_ids:)
      new(
        match_day:,
        selected_player_ids:,
        team_a_player_ids:,
        team_b_player_ids:
      ).call
    end

    def initialize(match_day:, selected_player_ids:, team_a_player_ids:, team_b_player_ids:)
      @match_day = match_day
      @selected_player_ids = normalize_ids(selected_player_ids)
      @team_a_player_ids = normalize_ids(team_a_player_ids)
      @team_b_player_ids = normalize_ids(team_b_player_ids)
    end

    def call
      return false unless valid_assignments?

      if manual_team_ids.empty?
        match_day.team_setups.destroy_all
        return true
      end

      team_setup = match_day.team_setups.first_or_create!
      team_setup.teams.where(team_type: "baseline").destroy_all

      TEAM_DEFINITIONS.each do |team_name, key|
        create_team(team_setup:, team_name:, player_ids: player_ids_for(key))
      end

      true
    end

    private

    attr_reader :match_day, :selected_player_ids, :team_a_player_ids, :team_b_player_ids

    def valid_assignments?
      if overlapping_player_ids.any?
        match_day.errors.add(:base, "Player cannot be assigned to both manual teams")
      end

      if invalid_player_ids.any?
        match_day.errors.add(:base, "Manual teams must use selected match day players only")
      end

      match_day.errors.none?
    end

    def overlapping_player_ids
      team_a_player_ids & team_b_player_ids
    end

    def invalid_player_ids
      manual_team_ids - selected_player_ids
    end

    def manual_team_ids
      (team_a_player_ids + team_b_player_ids).uniq
    end

    def create_team(team_setup:, team_name:, player_ids:)
      return if player_ids.empty?

      team = team_setup.teams.create!(name: team_name, team_type: "baseline")
      player_ids.each do |player_id|
        team.team_players.create!(player_id:)
      end
    end

    def normalize_ids(ids)
      Array(ids).reject(&:blank?).map(&:to_i).uniq
    end

    def player_ids_for(key)
      case key
      when :team_a_player_ids
        team_a_player_ids
      when :team_b_player_ids
        team_b_player_ids
      else
        []
      end
    end
  end
end
