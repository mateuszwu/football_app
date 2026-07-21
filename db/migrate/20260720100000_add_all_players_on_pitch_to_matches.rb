class AddAllPlayersOnPitchToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :all_players_on_pitch, :boolean, default: false, null: false
  end
end
