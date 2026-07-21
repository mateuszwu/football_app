class RenameAllPlayersOnPitchOnMatches < ActiveRecord::Migration[8.1]
  def change
    rename_column :matches, :all_players_on_pitch, :all_roster_players_on_pitch
  end
end
