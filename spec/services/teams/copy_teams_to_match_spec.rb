require "rails_helper"

RSpec.describe Teams::CopyTeamsToMatch do
  describe ".call" do
    it "copies baseline teams into the first match" do
      match_day = create(:match_day)
      team_setup = create(:team_setup, match_day: match_day)
      baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE, lineup_source: Team::LINEUP_SOURCE_MANUAL)
      baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE, lineup_source: Team::LINEUP_SOURCE_MANUAL)
      waiting_team = create(:team, team_setup:, name: "Waiting", team_type: Team::TEAM_TYPE_BASELINE, lineup_source: Team::LINEUP_SOURCE_MANUAL, playing: false)
      first_player = create(:player)
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
      waiting_player = create(:player, name: "Waiting Player", nickname: "waiting", phone: "+48999999997")
      create(:team_player, team: baseline_team_a, player: first_player)
      create(:team_player, team: baseline_team_b, player: second_player)
      create(:team_player, team: waiting_team, player: waiting_player)
      match = create(:match, match_day:, home_team: baseline_team_a, away_team: baseline_team_b)

      result = described_class.call(match:)

      expect(result).to be(true)
      expect(match.reload.home_team.team_type).to eq(Team::TEAM_TYPE_MATCH)
      expect(match.away_team.team_type).to eq(Team::TEAM_TYPE_MATCH)
      expect(match.home_team.match).to eq(match)
      expect(match.away_team.match).to eq(match)
      expect(match.home_team.source_team).to eq(baseline_team_a)
      expect(match.away_team.source_team).to eq(baseline_team_b)
      expect(match.home_team.lineup_source).to eq(Team::LINEUP_SOURCE_MANUAL)
      expect(match.away_team.lineup_source).to eq(Team::LINEUP_SOURCE_MANUAL)
      expect(match.home_team.players).to contain_exactly(first_player)
      expect(match.away_team.players).to contain_exactly(second_player)
      expect(match.teams.find_by!(name: "Waiting").players).to contain_exactly(waiting_player)
      expect(match.teams.find_by!(name: "Waiting")).not_to be_playing
    end

    it "copies the previous match teams for subsequent matches" do
      match_day = create(:match_day)
      team_setup = create(:team_setup, match_day: match_day)
      baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE)
      baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE)
      previous_match = create(:match, match_day:, home_team: baseline_team_a, away_team: baseline_team_b)
      home_player = create(:player)
      away_player = create(:player, name: "Away", nickname: "away", phone: "+48999999998")
      waiting_player = create(:player, name: "Waiting Player", nickname: "waiting", phone: "+48999999997")

      first_match_home = create(:team, team_setup:, match: previous_match, name: "Team A", team_type: Team::TEAM_TYPE_MATCH, lineup_source: Team::LINEUP_SOURCE_AUTO, source_team: baseline_team_a)
      first_match_away = create(:team, team_setup:, match: previous_match, name: "Team B", team_type: Team::TEAM_TYPE_MATCH, lineup_source: Team::LINEUP_SOURCE_AUTO, source_team: baseline_team_b)
      waiting_team = create(:team, team_setup:, match: previous_match, name: "Waiting", team_type: Team::TEAM_TYPE_MATCH, lineup_source: Team::LINEUP_SOURCE_MANUAL, playing: false)
      previous_match.update!(home_team: first_match_home, away_team: first_match_away)
      create(:team_player, team: first_match_home, player: home_player)
      create(:team_player, team: first_match_away, player: away_player)
      create(:team_player, team: waiting_team, player: waiting_player)

      current_match = create(:match, match_day:, home_team: baseline_team_a, away_team: baseline_team_b)

      result = described_class.call(match: current_match)

      expect(result).to be(true)
      expect(current_match.reload.home_team.source_team).to eq(first_match_home)
      expect(current_match.away_team.source_team).to eq(first_match_away)
      expect(current_match.home_team.players).to contain_exactly(home_player)
      expect(current_match.away_team.players).to contain_exactly(away_player)
      expect(current_match.home_team.match).to eq(current_match)
      expect(current_match.away_team.match).to eq(current_match)
      expect(current_match.teams.find_by!(name: "Waiting").players).to contain_exactly(waiting_player)
      expect(current_match.teams.find_by!(name: "Waiting")).not_to be_playing
    end

    it "does not mutate the previous match lineup when the new match changes" do
      match_day = create(:match_day)
      team_setup = create(:team_setup, match_day: match_day)
      baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE)
      baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE)
      previous_match = create(:match, match_day:, home_team: baseline_team_a, away_team: baseline_team_b)
      original_home_player = create(:player)
      replacement_player = create(:player, name: "Replacement", nickname: "replacement", phone: "+48999999998")

      first_match_home = create(:team, team_setup:, match: previous_match, name: "Team A", team_type: Team::TEAM_TYPE_MATCH, source_team: baseline_team_a)
      first_match_away = create(:team, team_setup:, match: previous_match, name: "Team B", team_type: Team::TEAM_TYPE_MATCH, source_team: baseline_team_b)
      previous_match.update!(home_team: first_match_home, away_team: first_match_away)
      create(:team_player, team: first_match_home, player: original_home_player)

      current_match = create(:match, match_day:, home_team: baseline_team_a, away_team: baseline_team_b)
      described_class.call(match: current_match)

      current_match.home_team.team_players.destroy_all
      current_match.home_team.team_players.create!(player: replacement_player)

      expect(previous_match.home_team.reload.players).to contain_exactly(original_home_player)
      expect(current_match.home_team.reload.players).to contain_exactly(replacement_player)
    end

    it "returns false when there are not enough source teams to copy" do
      match_day = create(:match_day)
      team_setup = create(:team_setup, match_day: match_day)
      baseline_team = create(:team, team_setup:, name: "Solo", team_type: Team::TEAM_TYPE_BASELINE)
      inactive_team = create(:team, team_setup:, name: "Waiting", team_type: Team::TEAM_TYPE_BASELINE, playing: false)
      match = create(:match, match_day:, home_team: baseline_team, away_team: inactive_team)

      result = described_class.call(match:)

      expect(result).to be(false)
    end
  end
end
