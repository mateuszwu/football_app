class RemoveActiveFromSeasons < ActiveRecord::Migration[8.1]
  def change
    remove_index :seasons, :active if index_exists?(:seasons, :active)
    remove_column :seasons, :active, :boolean if column_exists?(:seasons, :active)
  end
end
