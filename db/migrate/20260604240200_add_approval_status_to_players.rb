class AddApprovalStatusToPlayers < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:players, :approval_status)
      add_column :players, :approval_status, :string, null: false, default: "pending"
    end

    add_index :players, :approval_status unless index_exists?(:players, :approval_status)
  end
end
