class AddMatchToTeams < ActiveRecord::Migration[8.1]
  def change
    add_reference :teams, :match, foreign_key: true
  end
end
