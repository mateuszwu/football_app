class CreateMatchDayPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :match_day_players do |t|
      t.references :match_day, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true

      t.timestamps
    end

    add_index :match_day_players, %i[match_day_id player_id], unique: true
  end
end
