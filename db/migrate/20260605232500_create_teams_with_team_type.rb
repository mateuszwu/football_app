class CreateTeamsWithTeamType < ActiveRecord::Migration[8.1]
  def change
    if table_exists?(:teams)
      add_reference :teams, :team_setup, foreign_key: true
      add_column :teams, :team_type, :string
      add_index :teams, :team_type
    else
      create_table :teams do |t|
        t.string :name, null: false
        t.references :team_setup, null: false, foreign_key: true
        t.string :team_type, null: false

        t.timestamps
      end

      add_index :teams, :team_type
    end
  end
end
