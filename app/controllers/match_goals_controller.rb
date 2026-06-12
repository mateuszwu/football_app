class MatchGoalsController < ApplicationController
  before_action :require_admin!

  def create
    match = Match
      .includes(home_team: :players, away_team: :players)
      .find(params[:match_id])

    result = Matches::AddGoal.call(
      match:,
      scorer_team_player_id: goal_params[:scorer_team_player_id],
      scoring_team_id: goal_params[:scoring_team_id],
      assistant_team_player_id: goal_params[:assistant_team_player_id].presence
    )

    if result
      redirect_to match_path(match), notice: "Goal added"
    else
      redirect_to match_path(match), alert: "Could not add goal"
    end
  end

  def destroy
    match = Match.find(params[:match_id])
    goal = match.match_goals.find(params[:id])

    result = Matches::UndoGoal.call(match:, goal:)

    if result
      redirect_to match_path(match), notice: "Goal removed"
    else
      redirect_to match_path(match), alert: "Could not remove goal"
    end
  end

  private

  def goal_params
    params.expect(match_goal: [ :scorer_team_player_id, :scoring_team_id, :assistant_team_player_id ])
  end
end
