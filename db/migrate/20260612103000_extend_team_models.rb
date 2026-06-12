class ExtendTeamModels < ActiveRecord::Migration[8.1]
  def change
    change_table :team_setups, bulk: true do |t|
      t.string :setup_method
      t.string :algorithm_version
      t.datetime :accepted_at
    end

    change_table :teams, bulk: true do |t|
      t.references :source_team, foreign_key: { to_table: :teams }
      t.string :lineup_source, null: false, default: "manual"
      t.integer :position
      t.boolean :playing, null: false, default: true
      t.integer :score, null: false, default: 0
      t.string :result
      t.integer :elo_before
      t.integer :elo_after
      t.integer :elo_delta
    end

    change_table :team_players, bulk: true do |t|
      t.string :player_name, null: false
      t.string :role_code, null: false, default: "ANY"
      t.integer :position
      t.integer :elo_before
      t.integer :elo_after
      t.integer :elo_delta
    end
  end
end
