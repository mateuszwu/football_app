class AddAssistantToMatchGoals < ActiveRecord::Migration[8.1]
  def change
    add_reference :match_goals, :assistant, foreign_key: { to_table: :players }
  end
end
