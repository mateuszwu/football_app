class MatchPlayerChangesController < ApplicationController
  before_action :require_admin!

  def create
    match = Match.find(params[:match_id])
    result = Matches::RecordPlayerChange.call(
      match:,
      player: Player.find(player_change_params[:player_id]),
      from_team: team_for(player_change_params[:from_team_id]),
      to_team: team_for(player_change_params[:to_team_id]),
      occurred_at: parsed_occurred_at
    )

    if result
      redirect_to match_path(match), notice: "Player change recorded"
    else
      redirect_to match_path(match), alert: "Could not record player change"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to match_path(params[:match_id]), alert: "Could not record player change"
  end

  private

  def player_change_params
    params.expect(match_player_change: [ :player_id, :from_team_id, :to_team_id, :occurred_at ])
  end

  def team_for(team_id)
    return nil if team_id.blank?

    Team.find(team_id)
  end

  def parsed_occurred_at
    Time.zone.parse(player_change_params[:occurred_at].to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
