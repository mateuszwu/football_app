class AddProfileIdentityToPlayers < ActiveRecord::Migration[8.1]
  def up
    change_table :players, bulk: true do |t|
      t.string :profile_color_key
      t.string :profile_color_hex
      t.string :profile_icon
    end

    add_index :players, :profile_color_key
    add_index :players, :profile_icon
    add_index :players, %i[profile_color_key profile_icon]
  end

  def down
    remove_index :players, %i[profile_color_key profile_icon]
    remove_index :players, :profile_icon
    remove_index :players, :profile_color_key

    change_table :players, bulk: true do |t|
      t.remove :profile_icon
      t.remove :profile_color_hex
      t.remove :profile_color_key
    end
  end
end
