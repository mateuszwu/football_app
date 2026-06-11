class CreateMatchGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :match_goals do |t|
      t.references :match, null: false, foreign_key: true
      t.references :scoring_team, null: false, foreign_key: { to_table: :teams }
      t.references :scorer, null: false, foreign_key: { to_table: :players }
      t.datetime :scored_at, null: false

      t.timestamps
    end
  end
end
