class NormalizeLegacyMatchTimes < ActiveRecord::Migration[8.1]
  # These imports stored Polish wall-clock values as UTC. Later GPS imports
  # already contain the correct UTC instants and must remain unchanged.
  LEGACY_DATES = %w[
    2026-06-14 2026-06-21 2026-07-05 2026-07-12
    2026-08-02 2026-08-16 2026-08-23 2026-09-06
  ].freeze

  def up
    shift_times(-2.hours)
  end

  def down
    shift_times(2.hours)
  end

  private

  def shift_times(offset)
    dates = LEGACY_DATES.map { |date| connection.quote(date) }.join(", ")
    ids = select_values(<<~SQL)
      SELECT matches.id FROM matches
      INNER JOIN match_days ON match_days.id = matches.match_day_id
      WHERE match_days.played_on IN (#{dates})
    SQL
    return if ids.empty?

    match_ids = ids.map { |id| Integer(id) }.join(", ")
    shift_column("matches", "started_at", "id", match_ids, offset)
    shift_column("matches", "finished_at", "id", match_ids, offset)
    shift_column("match_goals", "scored_at", "match_id", match_ids, offset)
    shift_column("match_player_changes", "occurred_at", "match_id", match_ids, offset)
  end

  def shift_column(table, column, foreign_key, ids, offset)
    select_all("SELECT id, #{column} FROM #{table} WHERE #{foreign_key} IN (#{ids}) AND #{column} IS NOT NULL").each do |row|
      timestamp = (Time.parse("#{row.fetch(column)} UTC") + offset).strftime("%Y-%m-%d %H:%M:%S.%6N")
      execute "UPDATE #{table} SET #{column} = #{connection.quote(timestamp)} WHERE id = #{Integer(row.fetch('id'))}"
    end
  end
end
