module Voting
  class CalculateVoteBonuses
    def self.call(match_day:)
      new(match_day:).call
    end

    def initialize(match_day:)
      @match_day = match_day
      @season = match_day.season
    end

    def call
      MatchDay.transaction do
        sync_vote_bonus_changes!
        sync_vote_counts!
      end
    end

    private

    attr_reader :match_day, :season

    def sync_vote_bonus_changes!
      player_ids.each do |player_id|
        apply_player_bonus_change!(player_id)
      end
    end

    def apply_player_bonus_change!(player_id)
      player = Player.find(player_id)
      existing_change = existing_changes_by_player_id[player_id]
      current_bonus = current_bonus_totals.fetch(player_id, zero)
      previous_bonus = existing_change&.performance_delta || zero
      bonus_delta = current_bonus - previous_bonus

      apply_bonus_delta!(player:, bonus_delta:) unless bonus_delta.zero?
      sync_rating_change!(player:, existing_change:, current_bonus:)
    end

    def apply_bonus_delta!(player:, bonus_delta:)
      player_season_stat = Ratings::InitializePlayerSeasonStat.call(player:, season:)

      player_season_stat.update!(performance_score: player_season_stat.performance_score + bonus_delta)
      player.update!(global_performance_score: player.global_performance_score + bonus_delta)
    end

    def sync_rating_change!(player:, existing_change:, current_bonus:)
      if current_bonus.zero?
        existing_change&.destroy!
        return
      end

      attributes = {
        rating_scope: PlayerRatingChange::RATING_SCOPE_SEASON,
        source_type: PlayerRatingChange::SOURCE_TYPE_VOTE,
        reason: "vote_performance",
        performance_delta: current_bonus
      }

      if existing_change.present?
        existing_change.update!(attributes)
        return
      end

      Ratings::RecordPlayerRatingChange.call(
        player:,
        season:,
        match_day:,
        rating_scope: PlayerRatingChange::RATING_SCOPE_SEASON,
        source_type: PlayerRatingChange::SOURCE_TYPE_VOTE,
        reason: "vote_performance",
        performance_delta: current_bonus
      )
    end

    def sync_vote_counts!
      season_vote_player_ids.each do |player_id|
        player = Player.find(player_id)
        player_season_stat = Ratings::InitializePlayerSeasonStat.call(player:, season:)

        player_season_stat.update!(
          mvp_votes_count: season_mvp_vote_counts.fetch(player_id, 0),
          def_votes_count: season_def_vote_counts.fetch(player_id, 0)
        )
      end
    end

    def player_ids
      @player_ids ||= (current_bonus_totals.keys | existing_changes_by_player_id.keys)
    end

    def current_bonus_totals
      @current_bonus_totals ||= begin
        ids = match_day_mvp_vote_counts.keys | match_day_def_vote_counts.keys

        ids.each_with_object({}) do |player_id, totals|
          totals[player_id] = total_bonus_for(
            mvp_votes_count: match_day_mvp_vote_counts.fetch(player_id, 0),
            def_votes_count: match_day_def_vote_counts.fetch(player_id, 0)
          )
        end
      end
    end

    def total_bonus_for(mvp_votes_count:, def_votes_count:)
      mvp_bonus = proportional_bonus_for(max_points: season.mvp_max_points, votes_count: mvp_votes_count)
      def_bonus = proportional_bonus_for(max_points: season.def_max_points, votes_count: def_votes_count)

      [ mvp_bonus + def_bonus, season.voting_bonus_cap ].min
    end

    def proportional_bonus_for(max_points:, votes_count:)
      return zero if votes_count.zero?

      [ max_points * BigDecimal(votes_count.to_s) / season.expected_voters_count, max_points ].min
    end

    def existing_changes_by_player_id
      @existing_changes_by_player_id ||= season.player_rating_changes
                                           .where(match_day:, source_type: PlayerRatingChange::SOURCE_TYPE_VOTE)
                                           .index_by(&:player_id)
    end

    def season_vote_player_ids
      @season_vote_player_ids ||= (
        season_mvp_vote_counts.keys |
        season_def_vote_counts.keys |
        season.player_season_stats.where.not(mvp_votes_count: 0).pluck(:player_id) |
        season.player_season_stats.where.not(def_votes_count: 0).pluck(:player_id)
      )
    end

    def season_mvp_vote_counts
      @season_mvp_vote_counts ||= season_votes.group(:mvp_player_id).count
    end

    def season_def_vote_counts
      @season_def_vote_counts ||= season_votes.group(:def_player_id).count
    end

    def match_day_mvp_vote_counts
      @match_day_mvp_vote_counts ||= match_day_votes.group(:mvp_player_id).count
    end

    def match_day_def_vote_counts
      @match_day_def_vote_counts ||= match_day_votes.group(:def_player_id).count
    end

    def season_votes
      @season_votes ||= MatchDayVote
                          .joins(match_day_vote_token: { match_day_player: :match_day })
                          .where(match_days: { season_id: season.id })
    end

    def match_day_votes
      @match_day_votes ||= MatchDayVote
                             .joins(match_day_vote_token: { match_day_player: :match_day })
                             .where(match_days: { id: match_day.id })
    end

    def zero
      BigDecimal("0")
    end
  end
end
