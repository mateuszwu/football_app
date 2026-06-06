class AddRerollCountToTeamSetups < ActiveRecord::Migration[8.1]
  def change
    add_column :team_setups, :reroll_count, :integer, null: false, default: 0
  end
end
