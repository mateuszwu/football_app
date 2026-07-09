class MakePlayerPhoneOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :players, :phone, true
  end
end
