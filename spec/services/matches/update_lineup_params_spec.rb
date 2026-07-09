require "rails_helper"

RSpec.describe Matches::UpdateLineupParams do
  describe ".call" do
    context "when teams data is submitted as a hash" do
      it "returns normalized teams in value order" do
        params = {
          match: {
            teams_data: {
              "0" => { "id" => "10", "name" => "Team A", "captain_id" => "2", "player_ids" => [ "1", "2" ] },
              "1" => { "id" => "11", "name" => "Team B" }
            }
          }
        }

        result = described_class.call(params:)

        expect(result).to eq(
          [
            { id: "10", name: "Team A", captain_id: "2", player_ids: [ "1", "2" ] },
            { id: "11", name: "Team B", captain_id: nil, player_ids: [] }
          ]
        )
      end
    end

    context "when teams data is submitted as Action Controller params" do
      it "returns normalized teams from unsafe hashes" do
        params = ActionController::Parameters.new(
          match: {
            teams_data: [
              { id: "10", name: "Team A", player_ids: [ "1" ] }
            ]
          }
        )

        result = described_class.call(params:)

        expect(result).to eq(
          [
            { id: "10", name: "Team A", captain_id: nil, player_ids: [ "1" ] }
          ]
        )
      end
    end

    context "when teams data is missing" do
      it "returns an empty array" do
        params = {}

        result = described_class.call(params:)

        expect(result).to eq([])
      end
    end

    context "when a team object only responds to to_h" do
      it "returns normalized teams from plain object hashes" do
        team = Struct.new(:data) do
          def to_h
            data
          end
        end.new({ "id" => "10", "name" => "Team A", "player_ids" => [ "1" ] })
        params = {
          match: {
            teams_data: [ team ]
          }
        }

        result = described_class.call(params:)

        expect(result).to eq(
          [
            { id: "10", name: "Team A", captain_id: nil, player_ids: [ "1" ] }
          ]
        )
      end
    end
  end
end
