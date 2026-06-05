class CreateTeamSetups < ActiveRecord::Migration[8.1]
  def change
    create_table :team_setups do |t|
      t.references :match_day, null: false, foreign_key: true

      t.timestamps
    end
  end
end
