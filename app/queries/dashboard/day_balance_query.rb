module Dashboard
  class DayBalanceQuery
    TeamRecord = Struct.new(
      :name,
      :matches_played,
      :wins,
      :draws,
      :losses,
      :goals_for,
      :goals_against,
      :points,
      keyword_init: true
    ) do
      def goal_difference
        goals_for - goals_against
      end
    end

    PlayerRecord = Struct.new(:player, :goals, :assists, keyword_init: true) do
      def goal_assists
        goals + assists
      end
    end

    Summary = Struct.new(
      :match_day,
      :matches,
      :team_records,
      :total_goals,
      :total_assists,
      :top_player,
      keyword_init: true
    ) do
      def empty?
        match_day.blank?
      end

      def two_team_day?
        team_records.size == 2
      end

      def finished_matches_count
        matches.size
      end

      def first_match
        matches.first
      end
    end

    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      return empty_summary if season.blank? || last_finished_match_day.blank?

      Summary.new(
        match_day: last_finished_match_day,
        matches: finished_matches,
        team_records: team_records,
        total_goals: active_goals.size,
        total_assists: active_goals.count { |goal| goal.assistant_team_player_id.present? },
        top_player: top_player
      )
    end

    private

    attr_reader :season

    def empty_summary
      Summary.new(match_day: nil, matches: [], team_records: [], total_goals: 0, total_assists: 0, top_player: nil)
    end

    def last_finished_match_day
      @last_finished_match_day ||= season
        .match_days
        .finished
        .joins(:matches)
        .where(matches: { status: Match::STATUS_FINISHED })
        .order(played_on: :desc, id: :desc)
        .distinct
        .first
    end

    def finished_matches
      @finished_matches ||= last_finished_match_day
        .matches
        .where(status: Match::STATUS_FINISHED)
        .includes(:home_team, :away_team)
        .order(:finished_at, :created_at, :id)
        .to_a
    end

    def active_goals
      @active_goals ||= MatchGoal
        .active
        .joins(:match)
        .where(matches: { match_day_id: last_finished_match_day.id, status: Match::STATUS_FINISHED })
        .includes(scorer_team_player: :player, assistant_team_player: :player)
        .to_a
    end

    def team_records
      records = Hash.new { |hash, name| hash[name] = blank_team_record(name) }

      finished_matches.each do |match|
        home_record = records[match.home_team.name]
        away_record = records[match.away_team.name]

        apply_match_result(record: home_record, goals_for: match.home_score, goals_against: match.away_score)
        apply_match_result(record: away_record, goals_for: match.away_score, goals_against: match.home_score)
      end

      records.values.sort_by do |record|
        [ -record.points, -record.goal_difference, -record.goals_for, -record.wins, record.name ]
      end
    end

    def blank_team_record(name)
      TeamRecord.new(
        name:,
        matches_played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goals_for: 0,
        goals_against: 0,
        points: 0
      )
    end

    def apply_match_result(record:, goals_for:, goals_against:)
      record.matches_played += 1
      record.goals_for += goals_for
      record.goals_against += goals_against

      if goals_for > goals_against
        record.wins += 1
        record.points += 3
      elsif goals_for == goals_against
        record.draws += 1
        record.points += 1
      else
        record.losses += 1
      end
    end

    def top_player
      player_records.values.sort_by { |record| [ -record.goal_assists, -record.goals, -record.assists, record.player.name ] }.first
    end

    def player_records
      active_goals.each_with_object({}) do |goal, records|
        scorer_record = records[goal.scorer.id] ||= PlayerRecord.new(player: goal.scorer, goals: 0, assists: 0)
        scorer_record.goals += 1

        next if goal.assistant.blank?

        assistant_record = records[goal.assistant.id] ||= PlayerRecord.new(player: goal.assistant, goals: 0, assists: 0)
        assistant_record.assists += 1
      end
    end
  end
end
