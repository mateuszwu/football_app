require "rails_helper"

RSpec.describe MatchDays::ImportFromPayload do
  describe ".call" do
    context "when the payload has original teams and multiple matches" do
      it "creates one match day with separate match teams and goals per match" do
        season = create(:season, name: "Summer 2026")
        adam = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        jan = create(:player, name: "Jan Kowalski", nickname: "jan", phone: "+48222222222", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Wisniewski", nickname: "marek", phone: "+48333333333", approval_status: "approved", active: true)
        piotr = create(:player, name: "Piotr Zielinski", nickname: "piotr", phone: "+48444444444", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          original_teams: [
            { name: "Original A", players: [ "adam", "jan" ] },
            { name: "Original B", players: [ "marek", "piotr" ] }
          ],
          matches: [
            {
              started_at: "2026-06-19 19:00",
              finished_at: "2026-06-19 19:30",
              teams: [
                { name: "Team Red", players: [ "adam", "jan" ] },
                { name: "Team Blue", players: [ "marek", "piotr" ] }
              ],
              goals: [
                { team: "Team Red", scorer: "adam", assistant: "jan" },
                { team: "Team Blue", scorer: "marek" }
              ]
            },
            {
              started_at: "2026-06-19 19:35",
              teams: [
                { name: "Team Red", players: [ "adam", "marek" ] },
                { name: "Team Blue", players: [ "jan", "piotr" ] }
              ],
              goals: [
                { team: "Team Blue", scorer: "jan" }
              ]
            }
          ]
        }

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be_success
        expect(result.match_day.played_on).to eq(Date.new(2026, 6, 19))
        expect(result.match_day.status).to eq("in_progress")
        expect(result.matches.size).to eq(2)
        expect(result.match_day.teams.where(team_type: Team::TEAM_TYPE_BASELINE).pluck(:name)).to contain_exactly("Original A", "Original B")
        expect(result.match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH).count).to eq(4)

        first_match = result.matches.first
        second_match = result.matches.second
        expect(first_match).to be_finished
        expect(first_match.home_team.players).to contain_exactly(adam, jan)
        expect(first_match.away_team.players).to contain_exactly(marek, piotr)
        expect(first_match.home_score).to eq(1)
        expect(first_match.away_score).to eq(1)
        expect(first_match.match_goals.order(:scored_at).map { |goal| goal.scorer.nickname }).to eq(%w[adam marek])

        expect(second_match).to be_in_progress
        expect(second_match.home_team.players).to contain_exactly(adam, marek)
        expect(second_match.away_team.players).to contain_exactly(jan, piotr)
        expect(second_match.home_score).to eq(0)
        expect(second_match.away_score).to eq(1)
        expect(second_match.match_goals.order(:scored_at).map { |goal| goal.scorer.nickname }).to eq([ "jan" ])
      end
    end

    context "when the payload uses the legacy single-match shape" do
      it "creates one match from top-level teams and goals" do
        season = create(:season)
        first_player = create(:player, nickname: "first", approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          teams: [
            { name: "Team A", players: [ "first" ] },
            { name: "Team B", players: [ "second" ] }
          ],
          goals: [
            { team: "Team A", scorer: "first" }
          ]
        }

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be_success
        expect(result.matches.size).to eq(1)
        expect(result.match_day.status).to eq("in_progress")
        expect(result.match).to be_in_progress
        expect(result.match.started_at).to eq(Time.zone.parse("2026-06-19 18:00:00"))
        expect(result.match.finished_at).to be_nil
        expect(first_player.reload).to be_present
        expect(second_player.reload).to be_present
      end
    end

    context "when the payload is invalid" do
      it "returns errors and does not persist partial records" do
        season = create(:season)
        player = create(:player, nickname: "adam", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          original_teams: [
            { name: "Original A", players: [ "adam" ] },
            { name: "Original B", players: [ "ghost" ] }
          ],
          matches: [
            {
              teams: [
                { name: "Team A", players: [ "adam" ] },
                { name: "Team B", players: [ "ghost" ] }
              ],
              goals: [
                { team: "Team B", scorer: "ghost" }
              ]
            }
          ]
        }

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("Unknown approved active player: ghost")
        expect(MatchDay.count).to eq(0)
        expect(Match.count).to eq(0)
        expect(MatchGoal.count).to eq(0)
        expect(player.reload).to be_present
      end

      it "rejects match players that are missing from original teams" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        create(:player, name: "Ghost", nickname: "ghost", phone: "+48999999997", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          original_teams: [
            { name: "Original A", players: [ "adam" ] },
            { name: "Original B", players: [ "jan" ] }
          ],
          matches: [
            {
              teams: [
                { name: "Team A", players: [ "adam" ] },
                { name: "Team B", players: [ "ghost" ] }
              ],
              goals: [
                { team: "Team A", scorer: "adam" }
              ]
            }
          ]
        }

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("ghost in match 1 is not listed in original_teams")
        expect(MatchDay.count).to eq(0)
      end
    end
  end
end
