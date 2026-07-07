class AddOwnGoalToMatchGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :match_goals, :own_goal, :boolean, null: false, default: false
  end
end
