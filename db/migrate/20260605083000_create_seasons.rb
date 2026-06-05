class CreateSeasons < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on
      t.boolean :active, null: false, default: false
      t.integer :initial_elo, null: false, default: 1000
      t.integer :elo_k_factor, null: false, default: 32
      t.integer :mvp_vote_bonus, null: false, default: 10
      t.integer :def_vote_bonus, null: false, default: 10

      t.timestamps
    end

    add_index :seasons, :active
    add_index :seasons, :name, unique: true
    add_index :seasons, %i[starts_on ends_on]
  end
end
