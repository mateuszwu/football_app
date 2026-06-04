class AddRoleCodeToPlayers < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:players, :role_code)
      add_column :players, :role_code, :string, null: false, default: "ANY"
    end

    add_index :players, :role_code unless index_exists?(:players, :role_code)
  end
end
