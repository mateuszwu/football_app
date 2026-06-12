class PlayerRatingChange < ApplicationRecord
  RATING_SCOPE_GLOBAL = "global".freeze
  RATING_SCOPE_SEASON = "season".freeze
  RATING_SCOPES = [ RATING_SCOPE_GLOBAL, RATING_SCOPE_SEASON ].freeze

  SOURCE_TYPE_MATCH = "match".freeze
  SOURCE_TYPE_GOAL = "goal".freeze
  SOURCE_TYPE_ASSIST = "assist".freeze
  SOURCE_TYPE_VOTE = "vote".freeze
  SOURCE_TYPE_MANUAL = "manual".freeze
  SOURCE_TYPES = [
    SOURCE_TYPE_MATCH,
    SOURCE_TYPE_GOAL,
    SOURCE_TYPE_ASSIST,
    SOURCE_TYPE_VOTE,
    SOURCE_TYPE_MANUAL
  ].freeze

  belongs_to :player
  belongs_to :season
  belongs_to :match_day
  belongs_to :match, optional: true

  validates :rating_scope, inclusion: { in: RATING_SCOPES }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :reason, presence: true

  validates :old_elo_score, presence: true, if: :elo_source?
  validates :elo_delta, presence: true, if: :elo_source?
  validates :new_elo_score, presence: true, if: :elo_source?
  validates :performance_delta, presence: true, if: :performance_source?

  def elo_source?
    source_type == SOURCE_TYPE_MATCH
  end

  def performance_source?
    [ SOURCE_TYPE_GOAL, SOURCE_TYPE_ASSIST, SOURCE_TYPE_VOTE, SOURCE_TYPE_MANUAL ].include?(source_type)
  end
end
