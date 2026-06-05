class UpdateMatchDay
  def self.call(match_day:, params:, available_players:)
    new(match_day:, params:, available_players:).call
  end

  def initialize(match_day:, params:, available_players:)
    @match_day = match_day
    @params = params
    @available_players = available_players
  end

  def call
    MatchDay.transaction do
      match_day.update!(params)
      match_day.player_ids = selected_player_ids
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  attr_reader :available_players, :match_day, :params

  def selected_player_ids
    available_players.where(id: params.fetch(:player_ids, []).reject(&:blank?)).pluck(:id)
  end
end
