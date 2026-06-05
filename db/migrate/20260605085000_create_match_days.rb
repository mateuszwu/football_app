class CreateMatchDays < ActiveRecord::Migration[8.1]
  def change
    create_table :match_days do |t|
      t.references :season, null: false, foreign_key: true
      t.date :played_on, null: false
      t.string :status, null: false, default: "setup"

      t.timestamps
    end

    add_index :match_days, :status
    add_index :match_days, %i[season_id played_on], unique: true
  end
end
