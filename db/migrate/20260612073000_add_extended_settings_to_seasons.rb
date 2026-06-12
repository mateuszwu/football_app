class AddExtendedSettingsToSeasons < ActiveRecord::Migration[8.1]
  def up
    add_column :seasons, :status, :string, null: false, default: "active" unless column_exists?(:seasons, :status)
    add_column :seasons, :elo_k_value, :decimal, precision: 6, scale: 2, null: false, default: 16 unless column_exists?(:seasons, :elo_k_value)
    add_column :seasons, :player_advantage_elo, :decimal, precision: 6, scale: 2, null: false, default: 40 unless column_exists?(:seasons, :player_advantage_elo)
    add_column :seasons, :season_elo_carryover_factor, :decimal, precision: 4, scale: 2, null: false, default: 0.5 unless column_exists?(:seasons, :season_elo_carryover_factor)
    add_column :seasons, :goal_points, :decimal, precision: 6, scale: 2, null: false, default: 1.0 unless column_exists?(:seasons, :goal_points)
    add_column :seasons, :assist_points, :decimal, precision: 6, scale: 2, null: false, default: 0.8 unless column_exists?(:seasons, :assist_points)
    add_column :seasons, :mvp_max_points, :decimal, precision: 6, scale: 2, null: false, default: 4.0 unless column_exists?(:seasons, :mvp_max_points)
    add_column :seasons, :def_max_points, :decimal, precision: 6, scale: 2, null: false, default: 3.0 unless column_exists?(:seasons, :def_max_points)
    add_column :seasons, :voting_bonus_cap, :decimal, precision: 6, scale: 2, null: false, default: 5.0 unless column_exists?(:seasons, :voting_bonus_cap)
    add_column :seasons, :expected_voters_count, :integer, null: false, default: 5 unless column_exists?(:seasons, :expected_voters_count)
    add_column :seasons, :elo_settings_locked, :boolean, null: false, default: false unless column_exists?(:seasons, :elo_settings_locked)
    add_column :seasons, :elo_recalculated_at, :datetime unless column_exists?(:seasons, :elo_recalculated_at)

    add_index :seasons, :status unless index_exists?(:seasons, :status)

    Season.reset_column_information
    Season.find_each do |season|
      season.update_columns(status: season.active? ? "active" : "archived") if season.has_attribute?(:active)
    end
  end

  def down
    remove_index :seasons, :status if index_exists?(:seasons, :status)

    remove_column :seasons, :elo_recalculated_at if column_exists?(:seasons, :elo_recalculated_at)
    remove_column :seasons, :elo_settings_locked if column_exists?(:seasons, :elo_settings_locked)
    remove_column :seasons, :expected_voters_count if column_exists?(:seasons, :expected_voters_count)
    remove_column :seasons, :voting_bonus_cap if column_exists?(:seasons, :voting_bonus_cap)
    remove_column :seasons, :def_max_points if column_exists?(:seasons, :def_max_points)
    remove_column :seasons, :mvp_max_points if column_exists?(:seasons, :mvp_max_points)
    remove_column :seasons, :assist_points if column_exists?(:seasons, :assist_points)
    remove_column :seasons, :goal_points if column_exists?(:seasons, :goal_points)
    remove_column :seasons, :season_elo_carryover_factor if column_exists?(:seasons, :season_elo_carryover_factor)
    remove_column :seasons, :player_advantage_elo if column_exists?(:seasons, :player_advantage_elo)
    remove_column :seasons, :elo_k_value if column_exists?(:seasons, :elo_k_value)
    remove_column :seasons, :status if column_exists?(:seasons, :status)
  end
end
