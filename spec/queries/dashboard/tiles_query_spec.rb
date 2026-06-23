require "rails_helper"

RSpec.describe Dashboard::TilesQuery do
  describe ".call" do
    context "when no season data exists" do
      it "returns empty dashboard data without admin-only counts" do
        result = described_class.call(admin_signed_in: false)

        expect(result.current_season).to be_nil
        expect(result.nearest_match_day).to be_nil
        expect(result.day_balance).to be_empty
        expect(result.top_elo).to eq([])
        expect(result.top_scorers).to eq([])
        expect(result.top_assists).to eq([])
        expect(result.top_mvp).to eq([])
        expect(result.top_def).to eq([])
        expect(result.open_vote_tokens_count).to eq(0)
        expect(result.cast_vote_tokens_count).to eq(0)
        expect(result.pending_players_count).to be_nil
      end
    end

    context "when dashboard data exists" do
      it "builds season, match, ranking, voting, and relationship summaries" do
        season = create(:season, name: "Summer 2026", status: Season::STATUS_ACTIVE)
        first_player = create(:player, name: "Adam Nowak", nickname: "adam", approval_status: "approved", active: true, role_code: "ATT")
        second_player = create(:player, name: "Jan Kowal", nickname: "jan", approval_status: "approved", active: true, role_code: "MID")
        third_player = create(:player, name: "Marek Lis", nickname: "marek", approval_status: "approved", active: true, role_code: "DEF")
        create(:player, name: "Pending Player", nickname: "pending", approval_status: "pending", active: true)
        create(:player, name: "Inactive Player", nickname: "inactive", approval_status: "approved", active: false)

        match_day = create(:match_day, season:, played_on: Date.current + 1.day, status: "finished")
        [ first_player, second_player, third_player ].each do |player|
          create(:match_day_player, match_day:, player:)
        end
        token_match_day_player = MatchDayPlayer.find_by!(match_day:, player: first_player)
        create(:match_day_vote_token, match_day_player: token_match_day_player, expires_at: 2.days.from_now)
        cast_vote_match_day_player = MatchDayPlayer.find_by!(match_day:, player: second_player)
        create(
          :match_day_vote_token,
          match_day_player: cast_vote_match_day_player,
          expires_at: 1.day.ago,
          used_at: 1.hour.ago
        )

        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, name: "Orange Team", team_setup:, team_type: Team::TEAM_TYPE_MATCH, score: 2)
        away_team = create(:team, name: "Black Team", team_setup:, team_type: Team::TEAM_TYPE_MATCH, score: 1)
        match = create(
          :match,
          match_day:,
          home_team:,
          away_team:,
          home_score: 2,
          away_score: 1,
          started_at: 1.hour.ago,
          finished_at: 30.minutes.ago
        )
        scorer = create(:team_player, team: home_team, player: first_player)
        assistant = create(:team_player, team: home_team, player: second_player)
        create(:match_goal, match:, scoring_team: home_team, scorer_team_player: scorer, assistant_team_player: assistant)

        create(:player_season_stat, season:, player: first_player, elo: 1040, goals: 3, assists: 1, mvp_votes_count: 2)
        create(:player_season_stat, season:, player: second_player, elo: 1010, goals: 1, assists: 4, def_votes_count: 3)
        create(:player_season_stat, season:, player: third_player, elo: 990)

        result = described_class.call(admin_signed_in: true)

        expect(result.current_season).to eq(season)
        expect(result.nearest_match_day).to eq(match_day)
        expect(result.day_balance.match_day).to eq(match_day)
        expect(result.day_balance.first_match).to eq(match)
        expect(result.approved_active_players_count).to eq(3)
        expect(result.approved_players_count).to eq(4)
        expect(result.pending_players_count).to eq(1)
        expect(result.top_elo.map(&:player)).to eq([ first_player, second_player, third_player ])
        expect(result.top_scorers.map(&:player)).to eq([ first_player, second_player ])
        expect(result.top_assists.map(&:player)).to eq([ second_player, first_player ])
        expect(result.ranked_top_elo.map(&:rank)).to eq([ 1, 2, 3 ])
        expect(result.ranked_top_scorers.map(&:rank)).to eq([ 1, 2 ])
        expect(result.ranked_top_assists.map(&:rank)).to eq([ 1, 2 ])
        expect(result.top_mvp.first.player).to eq(first_player)
        expect(result.top_def.first.player).to eq(second_player)
        expect(result.open_vote_tokens_count).to eq(1)
        expect(result.cast_vote_tokens_count).to eq(1)
        expect(result.best_duo_summary.player_a).to eq(first_player)
        expect(result.best_duo_summary.player_b).to eq(second_player)
        expect(result.best_duo_summary.shared_match_days_count).to eq(1)
        expect(result.best_duo_summary.wins).to eq(1)
        expect(result.best_duo_summary.goals).to eq(1)
        expect(result.best_duo_summary.assists).to eq(1)
      end
    end
  end
end
