class AddApprovalTimestampsToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :approved_at, :datetime unless column_exists?(:players, :approved_at)
    add_column :players, :rejected_at, :datetime unless column_exists?(:players, :rejected_at)
  end
end
