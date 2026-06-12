class CreatePlayerRatingChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :player_rating_changes do |t|
      t.references :player, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.references :match_day, null: false, foreign_key: true
      t.references :match, foreign_key: true
      t.string :rating_scope, null: false
      t.string :source_type, null: false
      t.string :reason, null: false
      t.integer :old_elo_score
      t.integer :elo_delta
      t.integer :new_elo_score
      t.decimal :performance_delta, precision: 8, scale: 2
      t.decimal :elo_k_value, precision: 6, scale: 2
      t.decimal :player_advantage_elo, precision: 6, scale: 2

      t.timestamps
    end
  end
end
