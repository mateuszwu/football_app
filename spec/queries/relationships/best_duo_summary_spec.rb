require "rails_helper"

RSpec.describe Relationships::BestDuoSummary do
  describe ".call" do
    context "when there is no active relationship data" do
      it "returns an empty summary" do
        season = create(:season)

        result = described_class.call(season:)

        expect(result).to be_empty
        expect(result.shared_match_days_count).to eq(0)
        expect(result.record?).to be(false)
        expect(result.offensive_stats?).to be(false)
      end
    end

    context "when duos share finished match teams" do
      it "returns the relationships ranking leader with record, win rate, goals, and assists" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Demo", approval_status: "approved", active: true)
        dawid = create(:player, name: "Dawid Demo", approval_status: "approved", active: true)

        first_match_day = create(:match_day, season:, played_on: Date.current - 2.days, status: "finished")
        [ adam, bartek, cezary ].each do |player|
          create(:match_day_player, match_day: first_match_day, player:)
        end
        first_setup = create(:team_setup, match_day: first_match_day)
        first_home = create(:team, team_setup: first_setup, team_type: Team::TEAM_TYPE_MATCH)
        first_away = create(:team, team_setup: first_setup, team_type: Team::TEAM_TYPE_MATCH)
        first_adam = create(:team_player, team: first_home, player: adam)
        first_bartek = create(:team_player, team: first_home, player: bartek)
        create(:team_player, team: first_away, player: cezary)
        first_match = create(:match, match_day: first_match_day, home_team: first_home, away_team: first_away, home_score: 2, away_score: 1, finished_at: 2.days.ago)
        create(:match_goal, match: first_match, scoring_team: first_home, scorer_team_player: first_adam, assistant_team_player: first_bartek)
        create(:match_goal, match: first_match, scoring_team: first_home, scorer_team_player: first_bartek)

        second_match_day = create(:match_day, season:, played_on: Date.current - 1.day, status: "finished")
        [ adam, bartek, cezary, dawid ].each do |player|
          create(:match_day_player, match_day: second_match_day, player:)
        end
        second_setup = create(:team_setup, match_day: second_match_day)
        second_home = create(:team, team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH)
        second_away = create(:team, team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH)
        second_adam = create(:team_player, team: second_home, player: adam)
        create(:team_player, team: second_home, player: bartek)
        second_cezary = create(:team_player, team: second_away, player: cezary)
        create(:team_player, team: second_away, player: dawid)
        second_match = create(:match, match_day: second_match_day, home_team: second_home, away_team: second_away, home_score: 1, away_score: 1, finished_at: 1.day.ago)
        create(:match_goal, match: second_match, scoring_team: second_home, scorer_team_player: second_adam, undone_at: Time.current)

        third_match_day = create(:match_day, season:, played_on: Date.current, status: "finished")
        [ adam, bartek, cezary, dawid ].each do |player|
          create(:match_day_player, match_day: third_match_day, player:)
        end
        third_setup = create(:team_setup, match_day: third_match_day)
        third_home = create(:team, team_setup: third_setup, team_type: Team::TEAM_TYPE_MATCH)
        third_away = create(:team, team_setup: third_setup, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: third_home, player: adam)
        create(:team_player, team: third_home, player: bartek)
        third_cezary = create(:team_player, team: third_away, player: cezary)
        create(:team_player, team: third_away, player: dawid)
        third_match = create(:match, match_day: third_match_day, home_team: third_home, away_team: third_away, home_score: 0, away_score: 1, finished_at: Time.current)
        create(:match_goal, match: third_match, scoring_team: third_away, scorer_team_player: third_cezary)

        fourth_match_day = create(:match_day, season:, played_on: Date.current + 1.day, status: "finished")
        [ cezary, dawid ].each do |player|
          create(:match_day_player, match_day: fourth_match_day, player:)
        end
        fourth_setup = create(:team_setup, match_day: fourth_match_day)
        fourth_home = create(:team, team_setup: fourth_setup, team_type: Team::TEAM_TYPE_MATCH)
        fourth_away = create(:team, team_setup: fourth_setup, team_type: Team::TEAM_TYPE_MATCH)
        fourth_cezary = create(:team_player, team: fourth_home, player: cezary)
        create(:team_player, team: fourth_home, player: dawid)
        fourth_match = create(:match, match_day: fourth_match_day, home_team: fourth_home, away_team: fourth_away, home_score: 1, away_score: 0, finished_at: 1.hour.from_now)
        create(:match_goal, match: fourth_match, scoring_team: fourth_home, scorer_team_player: fourth_cezary)

        result = described_class.call(season:)

        expect(result.player_a).to eq(cezary)
        expect(result.player_b).to eq(dawid)
        expect(result.shared_match_days_count).to eq(3)
        expect(result.shared_matches_count).to eq(3)
        expect(result.wins).to eq(2)
        expect(result.draws).to eq(1)
        expect(result.losses).to eq(0)
        expect(result.win_rate).to eq(67)
        expect(result.goals).to eq(2)
        expect(result.assists).to eq(0)
      end
    end
  end
end
