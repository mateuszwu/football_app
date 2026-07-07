require "rails_helper"

RSpec.describe Synergy::GraphDataQuery do
  describe ".call" do
    context "when public players share finished match teams" do
      it "returns Cytoscape elements, metadata, and top connections" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", nickname: "adam", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Demo", nickname: "marek", approval_status: "approved", active: true)
        private_player = create(:player, name: "Private Demo", nickname: "private", approval_status: "pending", active: true)
        opponent = create(:player, name: "Opponent Demo", nickname: "opponent", approval_status: "approved", active: true)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 6, index + 1), status: "finished")
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: home_team, player: adam)
          marek_team_player = create(:team_player, team: home_team, player: marek)
          create(:team_player, team: home_team, player: private_player)
          create(:team_player, team: away_team, player: opponent)
          match = create(
            :match,
            match_day:,
            home_team:,
            away_team:,
            home_score: 2,
            away_score: 1,
            finished_at: index.days.ago
          )
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: marek_team_player)
        end

        result = described_class.call(
          season:,
          minimum_shared_matches: 3,
          player_filter: nil,
          limit: 50,
          metric: "shared_matches"
        )

        expect(result.fetch(:meta)).to include(
          players_count: 2,
          edges_count: 1,
          minimum_shared_matches: 3,
          limit: 50,
          metric: "shared_matches"
        )
        expect(result.fetch(:elements).count).to eq(3)
        expect(result.fetch(:elements).first.fetch(:data)).to include(:id, :label, :name, :role, :profile_path, :degree)
        expect(result.fetch(:elements).last.fetch(:data)).to include(
          label: "Adam Demo + Marek Demo",
          shared_matches: 3,
          wins: 3,
          win_rate: 100,
          goals: 3,
          assists: 3,
          goals_assists: 6,
          width: 3,
          color_group: "high"
        )
        expect(result.fetch(:top_connections).first).to include(label: "Adam Demo + Marek Demo", shared_matches: 3)
        expect(result.to_s).not_to include("Private Demo")
      end
    end

    context "when metric, limit, and player filter are applied" do
      it "filters before limiting and sorts by the selected metric" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", nickname: "adam", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Demo", nickname: "marek", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", nickname: "bartek", approval_status: "approved", active: true)
        opponent = create(:player, name: "Opponent Demo", nickname: "opponent", approval_status: "approved", active: true)

        match_day = create(:match_day, season:, played_on: Date.new(2026, 7, 1), status: "finished")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        adam_team_player = create(:team_player, team: home_team, player: adam)
        marek_team_player = create(:team_player, team: home_team, player: marek)
        create(:team_player, team: home_team, player: bartek)
        create(:team_player, team: away_team, player: opponent)
        match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: Time.current)
        create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: marek_team_player)

        result = described_class.call(
          season:,
          minimum_shared_matches: 1,
          player_filter: "marek",
          limit: 20,
          metric: "goals_assists"
        )

        expect(result.fetch(:meta)).to include(players_count: 3, edges_count: 2, metric: "goals_assists")
        expect(result.fetch(:top_connections).map { |connection| connection.fetch(:label) }).to eq(
          [ "Adam Demo + Marek Demo", "Marek Demo + Bartek Demo" ]
        )
      end

      it "keeps only graph edges connected to the selected player id" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", nickname: "adam", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Demo", nickname: "marek", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", nickname: "bartek", approval_status: "approved", active: true)
        opponent = create(:player, name: "Opponent Demo", nickname: "opponent", approval_status: "approved", active: true)

        match_day = create(:match_day, season:, played_on: Date.new(2026, 7, 2), status: "finished")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: adam)
        create(:team_player, team: home_team, player: marek)
        create(:team_player, team: home_team, player: bartek)
        create(:team_player, team: away_team, player: opponent)
        create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: Time.current)

        result = described_class.call(
          season:,
          minimum_shared_matches: 1,
          player_id: adam.id,
          limit: 20,
          metric: "shared_matches"
        )

        expect(result.fetch(:top_connections).map { |connection| connection.fetch(:label) }).to eq(
          [ "Adam Demo + Bartek Demo", "Adam Demo + Marek Demo" ]
        )
        expect(result.fetch(:elements).select { |element| element.fetch(:data).key?(:source) }).to all(
          satisfy { |edge| edge.fetch(:data).fetch(:source) == "player-#{adam.id}" || edge.fetch(:data).fetch(:target) == "player-#{adam.id}" }
        )
      end
    end

    context "when no relationships match" do
      it "returns empty graph data" do
        result = described_class.call(
          season: nil,
          minimum_shared_matches: 10,
          player_filter: "missing",
          limit: 100,
          metric: "win_rate"
        )

        expect(result.fetch(:elements)).to eq([])
        expect(result.fetch(:meta)).to include(players_count: 0, edges_count: 0, limit: 100, metric: "win_rate")
        expect(result.fetch(:top_connections)).to eq([])
      end

      it "normalizes unsupported limit and metric values" do
        result = described_class.call(season: nil, limit: 999, metric: "missing")

        expect(result.fetch(:meta)).to include(minimum_shared_matches: 1, limit: 50, metric: "shared_matches")
      end
    end

    context "when relationships have different match records" do
      it "tracks draws and losses and maps win rates to color groups" do
        season = create(:season)
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)
        celina = create(:player, name: "Celina Demo", approval_status: "approved", active: true)
        dominik = create(:player, name: "Dominik Demo", approval_status: "approved", active: true)
        ela = create(:player, name: "Ela Demo", approval_status: "approved", active: true)
        opponent = create(:player, name: "Opponent Demo", approval_status: "approved", active: true)

        create_shared_matches(season:, players: [ adam, marek ], opponent:, scores: [ [ 1, 0 ], [ 0, 1 ] ], day_offset: 0)
        create_shared_matches(season:, players: [ bartek, celina ], opponent:, scores: [ [ 1, 0 ], [ 0, 1 ], [ 0, 1 ], [ 0, 1 ] ], day_offset: 10)
        create_shared_matches(season:, players: [ dominik, ela ], opponent:, scores: [ [ 1, 1 ], [ 0, 1 ] ], day_offset: 20)

        result = described_class.call(season:, minimum_shared_matches: 1, metric: "win_rate")
        connections = result.fetch(:top_connections).index_by { |connection| connection.fetch(:label) }
        edges = result.fetch(:elements).select { |element| element.fetch(:data).key?(:source) }
        edge_by_label = edges.index_by { |edge| edge.fetch(:data).fetch(:label) }

        expect(connections.fetch("Adam Demo + Marek Demo")).to include(wins: 1, losses: 1, win_rate: 50)
        expect(connections.fetch("Bartek Demo + Celina Demo")).to include(wins: 1, losses: 3, win_rate: 25)
        expect(connections.fetch("Dominik Demo + Ela Demo")).to include(draws: 1, losses: 1, win_rate: 0)
        expect(edge_by_label.fetch("Adam Demo + Marek Demo").fetch(:data)).to include(color_group: "medium")
        expect(edge_by_label.fetch("Bartek Demo + Celina Demo").fetch(:data)).to include(color_group: "low")
        expect(edge_by_label.fetch("Dominik Demo + Ela Demo").fetch(:data)).to include(color_group: "low")
      end

      it "scales edge width by shared matches up to ten pixels" do
        query = described_class.new(season: nil, minimum_shared_matches: 1, player_filter: nil, limit: 50, metric: "shared_matches")

        expect(query.send(:edge_width_for, 1)).to eq(1)
        expect(query.send(:edge_width_for, 4)).to eq(4)
        expect(query.send(:edge_width_for, 30)).to eq(10)
      end
    end

    it "treats edges without shared matches as unrated" do
      edge = described_class::EdgeResult.new(shared_matches: 0, wins: 0)
      query = described_class.new(season: nil, minimum_shared_matches: 1, player_filter: nil, limit: 50, metric: "shared_matches")

      expect(edge.win_rate).to be_nil
      expect(query.send(:color_group_for, edge.win_rate)).to eq("hidden")
    end
  end

  def create_shared_matches(season:, players:, opponent:, scores:, day_offset:)
    scores.each_with_index do |(home_score, away_score), index|
      match_day = create(:match_day, season:, played_on: Date.new(2026, 8, 1) + day_offset + index, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      players.each { |player| create(:team_player, team: home_team, player:) }
      create(:team_player, team: away_team, player: opponent)
      create(:match, match_day:, home_team:, away_team:, home_score:, away_score:, finished_at: Time.current)
    end
  end
end
