class RemoveExpiresAtFromMatchDayVoteTokens < ActiveRecord::Migration[8.1]
  def change
    remove_column :match_day_vote_tokens, :expires_at, :datetime
  end
end
