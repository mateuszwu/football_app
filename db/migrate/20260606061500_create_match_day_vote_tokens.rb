class CreateMatchDayVoteTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :match_day_vote_tokens do |t|
      t.references :match_day_player, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :match_day_vote_tokens, :token, unique: true
  end
end
