require "rails_helper"

RSpec.describe Admin::MatchDays::FormState do
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
  end
end
