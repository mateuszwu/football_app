module Matches
  class RecordPlayerChange
    def self.call(match:, player:, from_team:, to_team:, occurred_at: Time.current)
      new(match:, player:, from_team:, to_team:, occurred_at:).call
    end

    def initialize(match:, player:, from_team:, to_team:, occurred_at:)
      @match = match
      @player = player
      @from_team = from_team
      @to_team = to_team
      @occurred_at = occurred_at
    end

    def call
      return false unless match.started_at.present?
      return false if match.elo_processed_at.present?
      return false unless player_is_available_for_match?
      return false unless transition_is_valid?

      Match.transaction do
        ensure_target_team_player!
        match.match_player_changes.create!(
          player:,
          from_team:,
          to_team:,
          event_type:,
          occurred_at:
        )
      end
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :player, :from_team, :to_team, :occurred_at

    def player_is_available_for_match?
      player.present? && match.match_day.players.exists?(player.id)
    end

    def transition_is_valid?
      return false if occurred_at.blank?
      return false if occurred_at < match.started_at
      return false if match.finished_at.present? && occurred_at > match.finished_at
      return false if from_team.blank? && to_team.blank?
      return false if from_team.present? && to_team.present? && from_team.id == to_team.id
      return false unless [ from_team, to_team ].compact.all? { |team| match.match_teams.include?(team) }
      return false if from_team.present? && !from_team.team_players.exists?(player:)

      current_team = match.player_team_at(player, occurred_at:)
      return false unless current_team == from_team

      true
    end

    def ensure_target_team_player!
      return if to_team.blank?

      to_team.team_players.find_or_create_by!(player:)
    end

    def event_type
      if from_team.present? && to_team.present?
        MatchPlayerChange::EVENT_TEAM_CHANGE
      elsif to_team.present?
        MatchPlayerChange::EVENT_SUBSTITUTION_IN
      else
        MatchPlayerChange::EVENT_SUBSTITUTION_OUT
      end
    end
  end
end
