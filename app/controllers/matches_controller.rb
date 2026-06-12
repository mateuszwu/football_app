class MatchesController < ApplicationController
  before_action :require_admin!, only: %i[copy_previous_lineup finish reset_to_baseline start update_lineup]

  def show
    match = Match
      .includes(
        match_day: :season,
        home_team: :players,
        away_team: :players
      )
      .find(params[:id])
    lineup_editor_state = Matches::LineupEditorState.call(match:)

    render :show, locals: { match:, lineup_editor_state: }
  end

  def start
    match = Match.find(params[:id])

    if Matches::StartMatch.call(match:)
      redirect_to match_path(match), notice: "Match started"
    else
      redirect_to match_path(match), alert: "Could not start match"
    end
  end

  def update_lineup
    match = Match.find(params[:id])

    if Teams::UpdateMatchLineup.call(match:, teams_data: Matches::UpdateLineupParams.call(params:))
      redirect_to match_path(match), notice: "Lineup updated"
    else
      redirect_to match_path(match), alert: match.errors.full_messages.to_sentence.presence || "Could not update lineup"
    end
  end

  def reset_to_baseline
    match = Match.find(params[:id])

    if Teams::CopyTeamsToMatch.call(match:, source: Teams::CopyTeamsToMatch::SOURCE_BASELINE)
      redirect_to match_path(match), notice: "Lineup reset to baseline"
    else
      redirect_to match_path(match), alert: "Could not reset lineup"
    end
  end

  def copy_previous_lineup
    match = Match.find(params[:id])

    if Teams::CopyTeamsToMatch.call(match:, source: Teams::CopyTeamsToMatch::SOURCE_PREVIOUS)
      redirect_to match_path(match), notice: "Previous match lineup copied"
    else
      redirect_to match_path(match), alert: "Could not copy previous lineup"
    end
  end

  def finish
    match = Match.find(params[:id])

    if Matches::FinishMatch.call(match:)
      redirect_to match_path(match), notice: "Match finished"
    else
      redirect_to match_path(match), alert: "Could not finish match"
    end
  end

  private
end
