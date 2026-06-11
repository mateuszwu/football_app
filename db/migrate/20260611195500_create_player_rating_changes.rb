class CreatePlayerRatingChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :player_rating_changes do |t|
      t.references :player, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.references :match, foreign_key: true
      t.integer :elo_before, null: false
      t.integer :elo_after, null: false
      t.integer :delta, null: false

      t.timestamps
    end
  end
end
