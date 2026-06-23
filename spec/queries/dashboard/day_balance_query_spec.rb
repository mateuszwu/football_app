require "rails_helper"

RSpec.describe Dashboard::DayBalanceQuery do
  describe ".call" do
    context "when there is no finished match day" do
      it "returns an empty summary" do
        season = create(:season)
        create(:match_day, season:, status: "ready")

        result = described_class.call(season:)

        expect(result).to be_empty
        expect(result.finished_matches_count).to eq(0)
        expect(result.total_goals).to eq(0)
        expect(result.total_assists).to eq(0)
      end
    end

    context "when the last finished match day has two teams" do
      it "summarizes match wins, draws, goals, assists, and top player" do
        season = create(:season)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 19), status: "finished")
        orange_player = create(:player, name: "Adam Nowak", nickname: "adam", approval_status: "approved")
        orange_assistant = create(:player, name: "Jan Kowal", nickname: "jan", approval_status: "approved")
        black_player = create(:player, name: "Marek Lis", nickname: "marek", approval_status: "approved")

        first_match = create_finished_match(match_day:, home_name: "Orange Team", away_name: "Black Team", home_score: 2, away_score: 1)
        second_match = create_finished_match(match_day:, home_name: "Orange Team", away_name: "Black Team", home_score: 0, away_score: 1)
        create_finished_match(match_day:, home_name: "Orange Team", away_name: "Black Team", home_score: 1, away_score: 1)

        create_goal(match: first_match, team: first_match.home_team, scorer: orange_player, assistant: orange_assistant)
        create_goal(match: first_match, team: first_match.home_team, scorer: orange_player)
        create_goal(match: second_match, team: second_match.away_team, scorer: black_player)
        create_goal(match: second_match, team: second_match.away_team, scorer: black_player, undone_at: Time.current)

        result = described_class.call(season:)
        records_by_name = result.team_records.index_by(&:name)
        orange_record = records_by_name.fetch("Orange Team")
        black_record = records_by_name.fetch("Black Team")

        expect(result.match_day).to eq(match_day)
        expect(result).to be_two_team_day
        expect(result.finished_matches_count).to eq(3)
        expect(result.total_goals).to eq(3)
        expect(result.total_assists).to eq(1)
        expect(orange_record.to_h.slice(:name, :wins, :draws, :losses, :points)).to eq(
          name: "Orange Team",
          wins: 1,
          draws: 1,
          losses: 1,
          points: 4
        )
        expect(black_record.to_h.slice(:name, :wins, :draws, :losses, :points)).to eq(
          name: "Black Team",
          wins: 1,
          draws: 1,
          losses: 1,
          points: 4
        )
        expect(result.top_player.player).to eq(orange_player)
        expect(result.top_player.goal_assists).to eq(2)
      end
    end

    context "when the last finished match day has more than two teams" do
      it "sorts the day table by points and tie breakers" do
        season = create(:season)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 19), status: "finished")

        create_finished_match(match_day:, home_name: "Orange Team", away_name: "Black Team", home_score: 3, away_score: 1)
        create_finished_match(match_day:, home_name: "White Team", away_name: "Green Team", home_score: 2, away_score: 0)
        create_finished_match(match_day:, home_name: "Orange Team", away_name: "White Team", home_score: 1, away_score: 1)
        create_finished_match(match_day:, home_name: "Black Team", away_name: "Green Team", home_score: 2, away_score: 0)

        result = described_class.call(season:)

        expect(result).not_to be_two_team_day
        expect(result.team_records.map { |record| [ record.name, record.points, record.wins, record.draws, record.losses ] }).to eq(
          [
            [ "Orange Team", 4, 1, 1, 0 ],
            [ "White Team", 4, 1, 1, 0 ],
            [ "Black Team", 3, 1, 0, 1 ],
            [ "Green Team", 0, 0, 0, 2 ]
          ]
        )
      end
    end
  end

  def create_finished_match(match_day:, home_name:, away_name:, home_score:, away_score:)
    team_setup = create(:team_setup, match_day:)
    home_team = create(:team, name: home_name, team_setup:, team_type: Team::TEAM_TYPE_MATCH, score: home_score)
    away_team = create(:team, name: away_name, team_setup:, team_type: Team::TEAM_TYPE_MATCH, score: away_score)
    create(
      :match,
      match_day:,
      home_team:,
      away_team:,
      home_score:,
      away_score:,
      started_at: 1.hour.ago,
      finished_at: 30.minutes.ago
    )
  end

  def create_goal(match:, team:, scorer:, assistant: nil, undone_at: nil)
    scorer_team_player = TeamPlayer.find_or_create_by!(team:, player: scorer) do |team_player|
      team_player.player_name = scorer.name
      team_player.role_code = scorer.role_code
    end
    assistant_team_player = if assistant.present?
      TeamPlayer.find_or_create_by!(team:, player: assistant) do |team_player|
        team_player.player_name = assistant.name
        team_player.role_code = assistant.role_code
      end
    end

    create(:match_goal, match:, scoring_team: team, scorer_team_player:, assistant_team_player:, undone_at:)
  end
end
