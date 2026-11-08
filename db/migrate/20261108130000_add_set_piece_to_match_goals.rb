class AddSetPieceToMatchGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :match_goals, :set_piece, :string
    add_check_constraint :match_goals, "set_piece IN ('free_kick', 'penalty')", name: "match_goals_valid_set_piece"
  end
end
