require "rails_helper"

RSpec.describe Players::PublicProfileQuery do
  describe ".call" do
    it "returns season-filtered stats and finished match history" do
      player = create(:player)
      spring = create(:season, name: "Spring 2026", starts_on: Date.new(2026, 3, 1))
      summer = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1))
      spring_match_day = create(:match_day, season: spring, status: "finished", played_on: Date.new(2026, 5, 20))
      summer_match_day = create(:match_day, season: summer, status: "finished", played_on: Date.new(2026, 6, 10))
      pending_match_day = create(:match_day, season: summer, status: "ready", played_on: Date.new(2026, 6, 17))
      spring_setup = create(:team_setup, match_day: spring_match_day)
      summer_setup = create(:team_setup, match_day: summer_match_day)
      pending_setup = create(:team_setup, match_day: pending_match_day)
      spring_team = create(:team, team_setup: spring_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_DRAW)
      spring_opp = create(:team, team_setup: spring_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_DRAW)
      summer_team = create(:team, team_setup: summer_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
      summer_opp = create(:team, team_setup: summer_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
      pending_team = create(:team, team_setup: pending_setup, team_type: Team::TEAM_TYPE_MATCH, result: nil)
      pending_opp = create(:team, team_setup: pending_setup, team_type: Team::TEAM_TYPE_MATCH, result: nil)
      create(:team_player, team: spring_team, player: player)
      create(:team_player, team: summer_team, player: player)
      create(:team_player, team: pending_team, player: player)
      create(:match, match_day: spring_match_day, home_team: spring_team, away_team: spring_opp, home_score: 1, away_score: 1, finished_at: Time.zone.parse("2026-05-20 20:00:00"))
      create(:match, match_day: summer_match_day, home_team: summer_team, away_team: summer_opp, home_score: 2, away_score: 0, finished_at: Time.zone.parse("2026-06-10 20:00:00"))
      create(:match, match_day: pending_match_day, home_team: pending_team, away_team: pending_opp, home_score: 0, away_score: 0, finished_at: nil)
      create(:player_season_stat, player:, season: spring, elo: 1010, goals: 1, assists: 2, mvp_votes_count: 3, def_votes_count: 1)
      create(:player_season_stat, player:, season: summer, elo: 1025, goals: 4, assists: 1, mvp_votes_count: 2, def_votes_count: 0)

      profile = described_class.call(player:, season_id: summer.id)

      expect(profile.available_seasons.map(&:name)).to eq([ "Summer 2026", "Spring 2026" ])
      expect(profile.selected_season).to eq(summer)
      expect(profile.season_stat).to have_attributes(elo: 1025, goals: 4, assists: 1, mvp_votes_count: 2, def_votes_count: 0)
      expect(profile.matches_count).to eq(1)
      expect(profile.wins).to eq(1)
      expect(profile.draws).to eq(0)
      expect(profile.losses).to eq(0)
      expect(profile.win_rate).to eq(100)
      expect(profile.match_entries.map { |entry| entry.match.match_day }).to eq([ summer_match_day ])
    end
  end
end
