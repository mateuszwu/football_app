class CreatePlayerSeasonStats < ActiveRecord::Migration[8.1]
  def change
    create_table :player_season_stats do |t|
      t.references :player, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.integer :elo

      t.timestamps
    end

    add_index :player_season_stats, [ :player_id, :season_id ], unique: true
  end
end
