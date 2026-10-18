require "rails_helper"
require Rails.root.join("db/migrate/20261018150000_normalize_legacy_match_times")

RSpec.describe NormalizeLegacyMatchTimes do
  it "normalizes legacy match and event timestamps and reverses without changing durations" do
    day = create(:match_day, played_on: Date.new(2026, 6, 14))
    home = create(:team, playing: true)
    away = create(:team, playing: true)
    scorer = create(:team_player, team: home)
    match = create(:match, match_day: day, home_team: home, away_team: away,
      started_at: Time.utc(2026, 6, 14, 10, 11, 47), finished_at: Time.utc(2026, 6, 14, 11, 19, 35))
    goal = create(:match_goal, match: match, scoring_team: home, scorer_team_player: scorer,
      scored_at: Time.utc(2026, 6, 14, 10, 41, 57, 123456))
    change = create(:match_player_change, match: match, player: scorer.player, from_team: home, to_team: away,
      occurred_at: Time.utc(2026, 6, 14, 11, 0))
    duration = match.finished_at - match.started_at
    original_created_at = goal.created_at
    migration = described_class.new

    migration.suppress_messages { migration.up }

    expect(match.reload.started_at.utc).to eq(Time.utc(2026, 6, 14, 8, 11, 47))
    expect(match.started_at.strftime("%H:%M")).to eq("10:11")
    expect(match.finished_at - match.started_at).to eq(duration)
    expect(goal.reload.scored_at.utc).to eq(Time.utc(2026, 6, 14, 8, 41, 57, 123456))
    expect(goal.created_at).to eq(original_created_at)
    expect(change.reload.occurred_at.utc).to eq(Time.utc(2026, 6, 14, 9, 0))

    migration.suppress_messages { migration.down }

    expect(match.reload.started_at.utc).to eq(Time.utc(2026, 6, 14, 10, 11, 47))
    expect(goal.reload.scored_at.utc).to eq(Time.utc(2026, 6, 14, 10, 41, 57, 123456))
    expect(change.reload.occurred_at.utc).to eq(Time.utc(2026, 6, 14, 11, 0))
  end

  it "keeps correctly stored GPS timestamps unchanged" do
    day = create(:match_day, played_on: Date.new(2026, 10, 18))
    match = create(:match, match_day: day, started_at: Time.utc(2026, 10, 18, 8, 18, 52, 80000))
    migration = described_class.new

    migration.suppress_messages { migration.up }
    migration.suppress_messages { migration.down }

    expect(match.reload.started_at.utc).to eq(Time.utc(2026, 10, 18, 8, 18, 52, 80000))
    expect(match.started_at.strftime("%H:%M")).to eq("10:18")
  end
end
