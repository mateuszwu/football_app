module MatchDays
  class ImportFromPayload
    Result = Struct.new(:success?, :match_day, :matches, :errors, keyword_init: true) do
      def match
        matches.first
      end
    end
    ParsedGoal = Struct.new(:team_name, :scorer_name, :assistant_name, :scored_at, :own_goal, keyword_init: true)

    def self.call(payload:, season:, available_players:)
      new(payload:, season:, available_players:).call
    end

    def initialize(payload:, season:, available_players:)
      @payload = payload.deep_symbolize_keys
      @season = season
      @available_players = available_players
      @errors = []
      @original_teams_data = []
      @matches_data = []
    end

    def call
      normalize_payload
      validate_payload
      return failure if errors.any?

      MatchDay.transaction do
        match_day = MatchDay.new
        created = CreateMatchDay.call(match_day:, params: match_day_params, available_players:)
        unless created
          errors.concat(match_day.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        team_setup = match_day.team_setups.first
        matches = matches_data.map do |match_data|
          create_imported_match!(match_day:, team_setup:, match_data:)
        end
        matches.zip(matches_data).each_with_index do |(match, match_data), index|
          process_imported_match!(match, match_data:, match_index: index)
        end
        recalculate_season_elo(match_day:)

        return Result.new(success?: true, match_day:, matches:, errors: [])
      end

      failure
    rescue ActiveRecord::RecordInvalid => error
      errors << error.record.errors.full_messages.to_sentence
      failure
    rescue ArgumentError => error
      errors << error.message
      failure
    end

    private

    attr_reader :available_players, :errors, :matches_data, :original_teams_data, :payload, :season

    def normalize_payload
      normalize_original_teams
      normalize_matches
    end

    def normalize_original_teams
      source_teams = payload[:original_teams].presence || payload[:teams]

      Array(source_teams).each do |team|
        original_teams_data << normalize_team(team)
      end
    end

    def normalize_matches
      if payload[:matches].present?
        Array(payload[:matches]).each do |match_payload|
          matches_data << normalize_match(
            match_payload,
            default_all_roster_players_on_pitch: payload[:all_roster_players_on_pitch]
          )
        end
        return
      end

      matches_data << normalize_match(
        {
          started_at: payload[:started_at],
          finished_at: payload[:finished_at],
          all_roster_players_on_pitch: payload[:all_roster_players_on_pitch],
          teams: payload[:teams],
          goals: payload[:goals]
        }
      )
    end

    def normalize_match(match_payload, default_all_roster_players_on_pitch: nil)
      match_data = match_payload.to_h.symbolize_keys
      all_roster_players_on_pitch = if match_data.key?(:all_roster_players_on_pitch)
        match_data[:all_roster_players_on_pitch]
      else
        default_all_roster_players_on_pitch
      end

      {
        started_at: match_data[:started_at],
        finished_at: match_data[:finished_at],
        all_roster_players_on_pitch: ActiveModel::Type::Boolean.new.cast(all_roster_players_on_pitch) || false,
        teams: Array(match_data[:teams]).map { |team| normalize_team(team) },
        goals: Array(match_data[:goals]).map { |goal| normalize_goal(goal) }
      }
    end

    def normalize_team(team)
      team_data = team.to_h.symbolize_keys
      {
        name: team_data[:name].to_s.strip,
        player_names: Array(team_data[:players]).map { |player_name| player_name.to_s.strip }.reject(&:blank?),
        captain_name: team_data[:captain].to_s.strip.presence
      }
    end

    def normalize_goal(goal)
      goal_data = goal.to_h.symbolize_keys
      ParsedGoal.new(
        team_name: goal_data[:team].to_s.strip,
        scorer_name: goal_data[:scorer].to_s.strip,
        assistant_name: goal_data[:assistant].to_s.strip.presence,
        scored_at: goal_data[:scored_at],
        own_goal: ActiveModel::Type::Boolean.new.cast(goal_data[:own_goal]) || false
      )
    end

    def validate_payload
      errors << "Season is required" if season.blank?
      errors << "played_on is required and must use YYYY-MM-DD" if played_on.blank?
      errors << "original_teams must contain at least two teams" if original_teams_data.size < 2
      errors << "matches must contain at least one match" if matches_data.empty?

      original_teams_data.each_with_index do |team, index|
        validate_team(team, label: "Original team #{index + 1}")
      end

      validate_matches
      validate_players
    end

    def validate_matches
      matches_data.each_with_index do |match_data, match_index|
        errors << "Match #{match_index + 1} must contain exactly two teams" unless match_data[:teams].size == 2
        errors << "Match #{match_index + 1} goals must contain at least one goal" if match_data[:goals].empty?

        match_data[:teams].each_with_index do |team, team_index|
          validate_team(team, label: "Match #{match_index + 1} team #{team_index + 1}")
        end

        validate_match_players_are_in_original_teams(match_data, match_index:)
        validate_match_goals(match_data, match_index:)
      end
    end

    def validate_team(team, label:)
      errors << "#{label} name is required" if team[:name].blank?
      errors << "#{team[:name].presence || label} needs at least one player" if team[:player_names].empty?
      return if team[:captain_name].blank?
      return if team[:player_names].any? { |player_name| same_player?(player_name, team[:captain_name]) }

      errors << "#{team[:captain_name]} must be listed in #{team[:name].presence || label} as a player"
    end

    def validate_match_players_are_in_original_teams(match_data, match_index:)
      match_data[:teams].flat_map { |team| team[:player_names] }.uniq.each do |player_name|
        next if original_player_names.any? { |original_player_name| same_player?(original_player_name, player_name) }

        errors << "#{player_name} in match #{match_index + 1} is not listed in original_teams"
      end
    end

    def validate_players
      imported_player_names.each do |player_name|
        errors << "Unknown approved active player: #{player_name}" unless player_for(player_name)
      end
    end

    def validate_match_goals(match_data, match_index:)
      match_data[:goals].each_with_index do |goal, goal_index|
        goal_number = goal_index + 1
        errors << "Match #{match_index + 1} goal #{goal_number} needs a team" if goal.team_name.blank?
        errors << "Match #{match_index + 1} goal #{goal_number} needs a scorer" if goal.scorer_name.blank?

        team = match_data[:teams].find { |team_data| same_name?(team_data[:name], goal.team_name) }
        unless team
          errors << "Match #{match_index + 1} goal #{goal_number} references unknown team: #{goal.team_name}"
          next
        end

        scorer_team = goal.own_goal ? opponent_team_for(match_data, team) : team
        unless scorer_team[:player_names].any? { |player_name| same_player?(player_name, goal.scorer_name) }
          errors << "#{goal.scorer_name} is not listed in #{scorer_team[:name]} for match #{match_index + 1}"
        end

        next if goal.assistant_name.blank?

        if goal.own_goal
          errors << "Own goal for #{goal.scorer_name} cannot have an assist"
          next
        end

        unless team[:player_names].any? { |player_name| same_player?(player_name, goal.assistant_name) }
          errors << "#{goal.assistant_name} is not listed in #{team[:name]} for match #{match_index + 1}"
        end

        errors << "Assistant cannot be the scorer for #{goal.scorer_name}" if same_player?(goal.scorer_name, goal.assistant_name)
      end
    end

    def create_imported_match!(match_day:, team_setup:, match_data:)
      match_teams = match_data[:teams].map do |team_data|
        create_match_team!(team_setup:, team_data:)
      end
      match = match_day.matches.create!(
        team_setup:,
        home_team: match_teams.first,
        away_team: match_teams.second,
        all_roster_players_on_pitch: match_data[:all_roster_players_on_pitch]
      )
      match_teams.each { |team| team.update!(match:) }

      match
    end

    def process_imported_match!(match, match_data:, match_index:)
      start_match!(match, match_data:, match_index:)
      create_goals!(match, match_data:, match_index:)
      finish_match!(match, match_data:, match_index:) if match_finished_at(match_data).present?
    end

    def create_match_team!(team_setup:, team_data:)
      team = team_setup.teams.create!(
        name: team_data[:name],
        team_type: Team::TEAM_TYPE_MATCH,
        lineup_source: Team::LINEUP_SOURCE_MANUAL,
        source_team: source_team_for(team_setup:, team_name: team_data[:name]),
        playing: true
      )

      team_data[:player_names].each_with_index do |player_name, position|
        player = player_for(player_name)
        team.team_players.create!(player:, position:)
      end
      team.update!(captain: player_for(team_data[:captain_name])) if team_data[:captain_name].present?

      team
    end

    def source_team_for(team_setup:, team_name:)
      team_setup.teams.find do |team|
        team.team_type == Team::TEAM_TYPE_BASELINE && same_name?(team.name, team_name)
      end
    end

    def start_match!(match, match_data:, match_index:)
      return if Matches::StartMatch.call(match:, started_at: match_started_at(match_data, match_index:))

      errors << "Could not start imported match #{match_index + 1}"
      raise ActiveRecord::Rollback
    end

    def create_goals!(match, match_data:, match_index:)
      match_data[:goals].each_with_index do |goal, goal_index|
        scoring_team = team_for(match, goal.team_name)
        result = Matches::AddGoal.call(
          match:,
          scoring_team_id: scoring_team.id,
          scorer_team_player_id: team_player_for(goal.own_goal ? opponent_team_for(match, scoring_team) : scoring_team, goal.scorer_name).id,
          assistant_team_player_id: goal.assistant_name.present? ? team_player_for(scoring_team, goal.assistant_name).id : nil,
          own_goal: goal.own_goal,
          scored_at: goal_scored_at(goal, match_data:, match_index:, goal_index:)
        )

        next if result

        errors << "Could not add goal #{goal_index + 1} for match #{match_index + 1}"
        raise ActiveRecord::Rollback
      end
    end

    def finish_match!(match, match_data:, match_index:)
      return if Matches::FinishMatch.call(match:, finished_at: match_finished_at(match_data))

      errors << "Could not finish imported match #{match_index + 1}"
      raise ActiveRecord::Rollback
    end

    def recalculate_season_elo(match_day:)
      return unless match_day.reload.status == "finished"

      Ratings::RecalculateSeasonElo.call(season:)
    end

    def match_day_params
      {
        season_id: season.id,
        played_on:,
        player_ids: original_players.map(&:id),
        teams_data: original_teams_data.map do |team|
          {
            name: team[:name],
            player_ids: team[:player_names].map { |player_name| player_for(player_name).id },
            captain_id: player_for(team[:captain_name])&.id
          }
        end
      }
    end

    def original_players
      original_player_names.map { |player_name| player_for(player_name) }.uniq
    end

    def imported_player_names
      (
        original_player_names +
        original_teams_data.filter_map { |team| team[:captain_name] } +
        matches_data.flat_map do |match_data|
          match_data[:teams].flat_map { |team| team[:player_names] + [ team[:captain_name] ].compact }
        end
      ).uniq
    end

    def original_player_names
      original_teams_data.flat_map { |team| team[:player_names] }.uniq
    end

    def player_for(player_name)
      return nil if player_name.blank?

      players_by_lookup[normalize(player_name)]
    end

    def players_by_lookup
      @players_by_lookup ||= available_players.each_with_object({}) do |player, lookup|
        lookup[normalize(player.name)] = player
        lookup[normalize(player.nickname)] = player
      end
    end

    def team_for(match, team_name)
      [ match.home_team, match.away_team ].find { |team| same_name?(team.name, team_name) }
    end

    def opponent_team_for(match_or_data, team)
      teams = match_or_data.is_a?(Match) ? [ match_or_data.home_team, match_or_data.away_team ] : match_or_data[:teams]
      teams.find { |candidate| candidate != team }
    end

    def team_player_for(team, player_name)
      player = player_for(player_name)
      team.team_players.find_by!(player:)
    end

    def played_on
      @played_on ||= Date.iso8601(payload[:played_on].to_s)
    rescue Date::Error
      nil
    end

    def match_started_at(match_data, match_index:)
      parse_time(match_data[:started_at]) || played_on.in_time_zone.change(hour: 18) + match_index.hours
    end

    def match_finished_at(match_data)
      parse_time(match_data[:finished_at])
    end

    def goal_scored_at(goal, match_data:, match_index:, goal_index:)
      parse_time(goal.scored_at) || match_started_at(match_data, match_index:) + (goal_index + 1).minutes
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    end

    def same_name?(first_name, second_name)
      normalize(first_name) == normalize(second_name)
    end

    def same_player?(first_name, second_name)
      player_for(first_name) == player_for(second_name)
    end

    def normalize(value)
      value.to_s.downcase.squish
    end

    def failure
      Result.new(success?: false, match_day: nil, matches: [], errors: errors.compact_blank.uniq)
    end
  end
end
