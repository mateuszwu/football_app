class CreateMatchDayVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :match_day_votes do |t|
      t.references :match_day_vote_token, null: false, foreign_key: true, index: { unique: true }
      t.references :mvp_player, null: false, foreign_key: { to_table: :players }
      t.references :def_player, null: false, foreign_key: { to_table: :players }
      t.datetime :submitted_at, null: false

      t.timestamps
    end
  end
end
