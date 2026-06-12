module Ratings
  class RecordPlayerRatingChange
    def self.call(player:, season:, match_day:, match: nil, rating_scope:, source_type:, reason:, old_elo_score: nil, elo_delta: nil, new_elo_score: nil, performance_delta: nil, elo_k_value: nil, player_advantage_elo: nil)
      new(
        player:,
        season:,
        match_day:,
        match:,
        rating_scope:,
        source_type:,
        reason:,
        old_elo_score:,
        elo_delta:,
        new_elo_score:,
        performance_delta:,
        elo_k_value:,
        player_advantage_elo:
      ).call
    end

    def initialize(player:, season:, match_day:, match:, rating_scope:, source_type:, reason:, old_elo_score:, elo_delta:, new_elo_score:, performance_delta:, elo_k_value:, player_advantage_elo:)
      @player = player
      @season = season
      @match_day = match_day
      @match = match
      @rating_scope = rating_scope
      @source_type = source_type
      @reason = reason
      @old_elo_score = old_elo_score
      @elo_delta = elo_delta
      @new_elo_score = new_elo_score
      @performance_delta = performance_delta
      @elo_k_value = elo_k_value
      @player_advantage_elo = player_advantage_elo
    end

    def call
      PlayerRatingChange.create!(
        player:,
        season:,
        match_day:,
        match:,
        rating_scope:,
        source_type:,
        reason:,
        old_elo_score:,
        elo_delta:,
        new_elo_score:,
        performance_delta:,
        elo_k_value:,
        player_advantage_elo:
      )
    end

    private

    attr_reader :player, :season, :match_day, :match, :rating_scope, :source_type, :reason, :old_elo_score, :elo_delta, :new_elo_score, :performance_delta, :elo_k_value, :player_advantage_elo
  end
end
