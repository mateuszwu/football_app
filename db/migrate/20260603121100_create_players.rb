class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.string :nickname, null: false
      t.string :phone, null: false
      t.text :description, null: false, default: ""
      t.boolean :active, null: false, default: true
      t.decimal :global_performance_score, precision: 8, scale: 2, null: false, default: 0.0

      t.timestamps
    end

    add_index :players, :active
    add_index :players, :nickname, unique: true
    add_index :players, :phone, unique: true
  end
end
