class AddEloToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :elo, :integer
  end
end
