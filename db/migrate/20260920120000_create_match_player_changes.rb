class CreateMatchPlayerChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :match_player_changes do |t|
      t.references :match, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :from_team, foreign_key: { to_table: :teams }
      t.references :to_team, foreign_key: { to_table: :teams }
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :match_player_changes, [ :match_id, :occurred_at, :id ], name: "idx_match_player_changes_on_match_and_time"
    add_index :match_player_changes, [ :match_id, :player_id ]
  end
end
