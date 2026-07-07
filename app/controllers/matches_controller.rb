class MatchesController < ApplicationController
  before_action :require_admin!, only: %i[copy_previous_lineup finish reset_to_baseline start update_lineup]

  def show
    match = Match
      .includes(
        match_day: :season,
        home_team: :players,
        away_team: :players,
        match_goals: [ :scoring_team, { scorer_team_player: :player, assistant_team_player: :player } ]
      )
      .find(params[:id])
    summary = Matches::SummaryQuery.call(match:)
    lineup_editor_state = Matches::LineupEditorState.call(match:)

    render :show, locals: { match:, summary:, lineup_editor_state: }
  end

  def start
    match = Match.find(params[:id])

    if Matches::StartMatch.call(match:)
      redirect_to match_path(match), notice: t("matches.started")
    else
      redirect_to match_path(match), alert: t("matches.start_failed")
    end
  end

  def update_lineup
    match = Match.find(params[:id])

    if Teams::UpdateMatchLineup.call(match:, teams_data: Matches::UpdateLineupParams.call(params:))
      redirect_to match_path(match), notice: t("matches.lineup_updated")
    else
      redirect_to match_path(match), alert: match.errors.full_messages.to_sentence.presence || t("matches.lineup_update_failed")
    end
  end

  def reset_to_baseline
    match = Match.find(params[:id])

    if Teams::CopyTeamsToMatch.call(match:, source: Teams::CopyTeamsToMatch::SOURCE_BASELINE)
      redirect_to match_path(match), notice: t("matches.lineup_reset")
    else
      redirect_to match_path(match), alert: t("matches.lineup_reset_failed")
    end
  end

  def copy_previous_lineup
    match = Match.find(params[:id])

    if Teams::CopyTeamsToMatch.call(match:, source: Teams::CopyTeamsToMatch::SOURCE_PREVIOUS)
      redirect_to match_path(match), notice: t("matches.previous_lineup_copied")
    else
      redirect_to match_path(match), alert: t("matches.previous_lineup_failed")
    end
  end

  def finish
    match = Match.find(params[:id])

    if Matches::FinishMatch.call(match:)
      redirect_to match_path(match), notice: t("matches.finished")
    else
      redirect_to match_path(match), alert: t("matches.finish_failed")
    end
  end

  private
end
