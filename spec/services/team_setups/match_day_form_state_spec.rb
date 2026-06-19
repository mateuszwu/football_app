require "rails_helper"

RSpec.describe TeamSetups::MatchDayFormState do
  describe "#locals" do
    it "returns persisted defaults for a new match day" do
      match_day = MatchDay.new
      players = Player.none
      state = described_class.new(match_day:, params: ActionController::Parameters.new, players:)

      expect(state.locals).to include(
        teams_data: [
          { name: "Team A", player_ids: [] },
          { name: "Team B", player_ids: [] }
        ],
        selected_player_ids: [],
        setup_method: TeamSetup::SETUP_METHOD_MANUAL,
        algorithm_version: nil,
        reroll_count: 0,
        team_count: 2
      )
    end

    it "builds auto preview locals outside the controller" do
      season = create(:season)
      first_player = create(:player, approval_status: "approved", active: true)
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
      third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997", approval_status: "approved", active: true)
      players = Player.where(id: [ first_player.id, second_player.id, third_player.id ])
      params = ActionController::Parameters.new(
        preview_auto_proposal: "1",
        match_day: {
          season_id: season.id.to_s,
          player_ids: [ first_player.id.to_s, second_player.id.to_s, third_player.id.to_s ],
          team_count: "3",
          reroll_count: "0"
        }
      )

      state = described_class.new(match_day: MatchDay.new, params:, players:)

      expect(state.preview_auto_proposal_requested?).to be(true)
      expect(state.locals[:team_count]).to eq(3)
      expect(state.locals[:teams_data].map { |team| team[:name] }).to eq([ "Team A", "Team B", "Team C" ])
      expect(state.locals[:setup_method]).to eq(TeamSetup::SETUP_METHOD_AUTO)
    end

    it "uses submitted hash teams data to infer team count" do
      first_player = create(:player, approval_status: "approved", active: true)
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
      third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997", approval_status: "approved", active: true)
      players = Player.where(id: [ first_player.id, second_player.id, third_player.id ])
      params = ActionController::Parameters.new(
        match_day: {
          player_ids: [ first_player.id.to_s, second_player.id.to_s, third_player.id.to_s ],
          teams_data: {
            "0" => { name: "Team A", player_ids: [ first_player.id.to_s ] },
            "1" => { name: "Team B", player_ids: [ second_player.id.to_s ] },
            "2" => { name: "Team C", player_ids: [ third_player.id.to_s ] }
          }
        }
      )

      state = described_class.new(match_day: MatchDay.new, params:, players:)

      expect(state.locals[:team_count]).to eq(3)
      expect(state.locals[:teams_data]).to eq(
        [
          { name: "Team A", player_ids: [ first_player.id.to_s ] },
          { name: "Team B", player_ids: [ second_player.id.to_s ] },
          { name: "Team C", player_ids: [ third_player.id.to_s ] }
        ]
      )
    end

    it "uses persisted baseline team count for existing match days" do
      match_day = create(:match_day)
      team_setup = create(:team_setup, match_day:)
      first_player = create(:player, approval_status: "approved", active: true)
      second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
      third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997", approval_status: "approved", active: true)
      [ first_player, second_player, third_player ].each { |player| create(:match_day_player, match_day:, player:) }
      create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE)
      create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE)
      create(:team, team_setup:, name: "Team C", team_type: Team::TEAM_TYPE_BASELINE)
      players = Player.where(id: [ first_player.id, second_player.id, third_player.id ])
      params = ActionController::Parameters.new

      state = described_class.new(match_day:, params:, players:)

      expect(state.locals[:team_count]).to eq(3)
      expect(state.locals[:teams_data].map { |team| team[:name] }).to eq([ "Team A", "Team B", "Team C" ])
    end

    it "uses numeric team names after Team Z" do
      players = create_list(:player, 27, approval_status: "approved", active: true)
      params = ActionController::Parameters.new(
        match_day: {
          player_ids: players.map { |player| player.id.to_s },
          team_count: "27"
        }
      )

      state = described_class.new(match_day: MatchDay.new, params:, players: Player.where(id: players.map(&:id)))

      expect(state.locals[:team_count]).to eq(27)
      expect(state.locals[:teams_data].last).to eq(name: "Team 27", player_ids: [])
    end
  end
end
