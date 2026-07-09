class AddCaptainToTeams < ActiveRecord::Migration[8.1]
  def change
    add_reference :teams, :captain, foreign_key: { to_table: :players }, null: true
  end
end
