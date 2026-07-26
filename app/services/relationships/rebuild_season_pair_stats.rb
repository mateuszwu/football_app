module Relationships
  class RebuildSeasonPairStats
    INSERT_BATCH_SIZE = 500
    EMPTY_METRICS = {
      shared_match_days_count: 0,
      shared_matches_count: 0,
      wins: 0,
      draws: 0,
      losses: 0,
      goals: 0,
      assists: 0,
      mutual_assists: 0,
      goal_difference: 0
    }.freeze

    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
      @stats = {}
    end

    def call
      aggregate_shared_match_days
      aggregate_finished_matches
      persist_stats

      stats.size
    end

    private

    attr_reader :season, :stats

    def aggregate_shared_match_days
      player_rows = MatchDayPlayer
        .joins(:match_day)
        .where(match_days: { season_id: season.id })
        .pluck(:match_day_id, :player_id)

      player_rows.group_by(&:first).each_value do |rows|
        player_ids = rows.map(&:second).uniq.sort
        player_ids.combination(2) { |pair| stats_for(pair)[:shared_match_days_count] += 1 }
      end
    end

    def aggregate_finished_matches
      matches.each do |match_id, home_team_id, away_team_id, home_score, away_score|
        aggregate_team(
          match_id:,
          team_id: home_team_id,
          goals_for: home_score,
          goals_against: away_score
        )
        aggregate_team(
          match_id:,
          team_id: away_team_id,
          goals_for: away_score,
          goals_against: home_score
        )
      end
    end

    def aggregate_team(match_id:, team_id:, goals_for:, goals_against:)
      player_ids = player_ids_by_team.fetch(team_id, [])
      offense = offense_by_match_and_team.fetch([ match_id, team_id ], empty_offense)

      player_ids.combination(2) do |pair|
        pair_stats = stats_for(pair)
        pair_stats[:shared_matches_count] += 1
        pair_stats[:goals] += pair.sum { |player_id| offense.fetch(:goals).fetch(player_id, 0) }
        pair_stats[:assists] += pair.sum { |player_id| offense.fetch(:assists).fetch(player_id, 0) }
        pair_stats[:mutual_assists] += offense.fetch(:mutual_assists).fetch(pair, 0)
        pair_stats[:goal_difference] += goals_for - goals_against
        apply_result(pair_stats:, goals_for:, goals_against:)
      end
    end

    def apply_result(pair_stats:, goals_for:, goals_against:)
      if goals_for > goals_against
        pair_stats[:wins] += 1
      elsif goals_for == goals_against
        pair_stats[:draws] += 1
      else
        pair_stats[:losses] += 1
      end
    end

    def matches
      @matches ||= Match
        .joins(:match_day)
        .where(status: Match::STATUS_FINISHED, match_days: { season_id: season.id })
        .pluck(:id, :home_team_id, :away_team_id, :home_score, :away_score)
    end

    def player_ids_by_team
      @player_ids_by_team ||= begin
        team_ids = matches.flat_map { |row| [ row[1], row[2] ] }.uniq

        TeamPlayer
          .where(team_id: team_ids)
          .pluck(:team_id, :player_id)
          .group_by(&:first)
          .transform_values { |rows| rows.map(&:second).uniq.sort }
      end
    end

    def offense_by_match_and_team
      @offense_by_match_and_team ||= begin
        offense = Hash.new { |hash, key| hash[key] = empty_offense }

        active_goal_rows.each do |match_id, scoring_team_id, own_goal, scorer_id, assistant_id|
          next if own_goal

          team_offense = offense[[ match_id, scoring_team_id ]]
          team_offense.fetch(:goals)[scorer_id] += 1
          next if assistant_id.blank?

          team_offense.fetch(:assists)[assistant_id] += 1
          team_offense.fetch(:mutual_assists)[pair_key(scorer_id, assistant_id)] += 1
        end

        offense
      end
    end

    def active_goal_rows
      MatchGoal
        .active
        .joins("INNER JOIN team_players scorer_pair_team_players ON scorer_pair_team_players.id = match_goals.scorer_team_player_id")
        .joins("LEFT JOIN team_players assistant_pair_team_players ON assistant_pair_team_players.id = match_goals.assistant_team_player_id")
        .where(match_id: matches.map(&:first))
        .pluck(
          :match_id,
          :scoring_team_id,
          :own_goal,
          "scorer_pair_team_players.player_id",
          "assistant_pair_team_players.player_id"
        )
    end

    def empty_offense
      {
        goals: Hash.new(0),
        assists: Hash.new(0),
        mutual_assists: Hash.new(0)
      }
    end

    def stats_for(player_ids)
      stats[pair_key(*player_ids)] ||= EMPTY_METRICS.dup
    end

    def pair_key(first_player_id, second_player_id)
      [ first_player_id, second_player_id ].sort
    end

    def persist_stats
      generated_at = Time.current
      rows = stats.map do |(player_one_id, player_two_id), metrics|
        {
          season_id: season.id,
          player_one_id:,
          player_two_id:,
          **metrics,
          created_at: generated_at,
          updated_at: generated_at
        }
      end

      SeasonPairStat.transaction do
        season.season_pair_stats.delete_all
        rows.each_slice(INSERT_BATCH_SIZE) { |batch| SeasonPairStat.insert_all!(batch) }
        season.update_columns(pair_stats_generated_at: generated_at)
      end
    end
  end
end
