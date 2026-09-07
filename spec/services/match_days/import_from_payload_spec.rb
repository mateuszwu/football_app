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
            { name: "Original A", players: [ "adam", "jan" ], captain: "adam" },
            { name: "Original B", players: [ "marek", "piotr" ], captain: "marek" }
          ],
          matches: [
            {
              started_at: "2026-06-19 19:00",
              finished_at: "2026-06-19 19:30",
              all_roster_players_on_pitch: true,
              teams: [
                { name: "Team Red", players: [ "adam", "jan" ], captain: "jan" },
                { name: "Team Blue", players: [ "marek", "piotr" ], captain: "piotr" }
              ],
              goals: [
                { team: "Team Red", scorer: "adam", assistant: "jan", scored_at: "2026-06-19 19:01:34" },
                { team: "Team Blue", scorer: "marek", scored_at: "2026-06-19 19:12:34" }
              ]
            },
            {
              started_at: "2026-06-19 19:35",
              teams: [
                { name: "Team Red", players: [ "adam", "marek" ], captain: "marek" },
                { name: "Team Blue", players: [ "jan", "piotr" ], captain: "jan" }
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
        ranking = Synergy::CombinationRankingQuery.call(
          season:,
          combination_size: 2,
          direction: "best",
          limit: 20,
          minimum_shared_matches: 1
        )
        imported_finished_pair = ranking.find { |entry| entry.players.map(&:id).sort == [ adam.id, jan.id ].sort }

        expect(result).to be_success
        expect(result.match_day.played_on).to eq(Date.new(2026, 6, 19))
        expect(result.match_day.status).to eq("in_progress")
        expect(result.matches.size).to eq(2)
        expect(result.match_day.teams.where(team_type: Team::TEAM_TYPE_BASELINE).pluck(:name)).to contain_exactly("Original A", "Original B")
        expect(result.match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH).count).to eq(4)
        expect(result.match_day.teams.find_by!(name: "Original A", team_type: Team::TEAM_TYPE_BASELINE).captain).to eq(adam)
        expect(result.match_day.teams.find_by!(name: "Original B", team_type: Team::TEAM_TYPE_BASELINE).captain).to eq(marek)

        first_match = result.matches.first
        second_match = result.matches.second
        expect(first_match).to be_finished
        expect(first_match).to be_all_roster_players_on_pitch
        expect(first_match.home_team.players).to contain_exactly(adam, jan)
        expect(first_match.away_team.players).to contain_exactly(marek, piotr)
        expect(first_match.home_team.captain).to eq(jan)
        expect(first_match.away_team.captain).to eq(piotr)
        expect(first_match.home_score).to eq(1)
        expect(first_match.away_score).to eq(1)
        expect(first_match.match_goals.order(:scored_at).map { |goal| goal.scorer.nickname }).to eq(%w[adam marek])
        expect(first_match.match_goals.order(:scored_at).map(&:scored_at)).to eq(
          [
            Time.zone.parse("2026-06-19 19:01:34"),
            Time.zone.parse("2026-06-19 19:12:34")
          ]
        )

        expect(second_match).to be_in_progress
        expect(second_match).not_to be_all_roster_players_on_pitch
        expect(second_match.home_team.players).to contain_exactly(adam, marek)
        expect(second_match.away_team.players).to contain_exactly(jan, piotr)
        expect(second_match.home_team.captain).to eq(marek)
        expect(second_match.away_team.captain).to eq(jan)
        expect(second_match.home_score).to eq(0)
        expect(second_match.away_score).to eq(1)
        expect(second_match.match_goals.order(:scored_at).map { |goal| goal.scorer.nickname }).to eq([ "jan" ])
        expect(imported_finished_pair).to have_attributes(
          shared_matches_count: 1,
          draws: 1,
          goals: 1,
          assists: 1,
          mutual_assists: 1
        )
      end
    end

    context "when every imported match is finished" do
      it "recalculates season Elo after importing the match day" do
        season = create(:season, initial_elo: 1000, elo_k_value: 16.0)
        home_player = create(
          :player,
          name: "Home Player",
          nickname: "home",
          elo: 1000,
          approval_status: "approved",
          active: true
        )
        away_player = create(
          :player,
          name: "Away Player",
          nickname: "away",
          elo: 1000,
          approval_status: "approved",
          active: true
        )
        payload = {
          played_on: "2026-06-19",
          started_at: "2026-06-19 19:00",
          finished_at: "2026-06-19 19:30",
          all_roster_players_on_pitch: true,
          teams: [
            { name: "Team Home", players: [ "home" ] },
            { name: "Team Away", players: [ "away" ] }
          ],
          goals: [
            { team: "Team Home", scorer: "home", scored_at: "2026-06-19 19:10" }
          ]
        }

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).to be_success
        expect(result.match_day.status).to eq("finished")
        expect(result.match.reload.elo_processed_at).to be_present
        expect(PlayerSeasonStat.find_by!(season:, player: home_player).elo).to eq(1008)
        expect(PlayerSeasonStat.find_by!(season:, player: away_player).elo).to eq(992)
        expect(season.reload.elo_recalculated_at).to be_present
      end
    end

    context "when the payload uses the legacy single-match shape" do
      it "creates one match from top-level teams and goals" do
        season = create(:season)
        first_player = create(:player, nickname: "first", approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          all_roster_players_on_pitch: true,
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
        expect(result.match).to be_all_roster_players_on_pitch
        expect(result.match.started_at).to eq(Time.zone.parse("2026-06-19 18:00:00"))
        expect(result.match.finished_at).to be_nil
        expect(result.match.elo_processed_at).to be_nil
        expect(season.reload.elo_recalculated_at).to be_nil
        expect(first_player.reload).to be_present
        expect(second_player.reload).to be_present
      end

      it "imports an own goal with the scorer from the opponent team" do
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
            { team: "Team A", scorer: "second", own_goal: true }
          ]
        }

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        goal = result.match.match_goals.first

        expect(result).to be_success
        expect(result.match.home_score).to eq(1)
        expect(result.match.away_score).to eq(0)
        expect(goal).to be_own_goal
        expect(goal.scoring_team.name).to eq("Team A")
        expect(goal.scorer).to eq(second_player)
        expect(first_player.reload).to be_present
      end
    end

    context "when the payload is invalid" do
      it "returns structural validation errors" do
        player = create(:player, nickname: "adam", approval_status: "approved", active: true)
        payload = {
          played_on: "not-a-date",
          original_teams: [
            { name: "", players: [] }
          ],
          matches: [
            {
              teams: [
                { name: "", players: [] }
              ],
              goals: []
            }
          ]
        }

        result = described_class.call(
          payload:,
          season: nil,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("Season is required")
        expect(result.errors).to include("played_on is required and must use YYYY-MM-DD")
        expect(result.errors).to include("original_teams must contain at least two teams")
        expect(result.errors).to include("Original team 1 name is required")
        expect(result.errors).to include("Original team 1 needs at least one player")
        expect(result.errors).to include("Match 1 must contain exactly two teams")
        expect(result.errors).to include("Match 1 goals must contain at least one goal")
        expect(result.errors).to include("Match 1 team 1 name is required")
        expect(result.errors).to include("Match 1 team 1 needs at least one player")
        expect(MatchDay.count).to eq(0)
        expect(player.reload).to be_present
      end

      it "returns goal validation errors" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        create(:player, name: "Ghost", nickname: "ghost", phone: "+48999999997", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          original_teams: [
            { name: "Original A", players: [ "adam", "ghost" ] },
            { name: "Original B", players: [ "jan" ] }
          ],
          matches: [
            {
              teams: [
                { name: "Team A", players: [ "adam" ] },
                { name: "Team B", players: [ "jan" ] }
              ],
              goals: [
                { team: "", scorer: "" },
                { team: "Missing", scorer: "adam" },
                { team: "Team B", scorer: "adam", assistant: "ghost" },
                { team: "Team B", scorer: "jan", assistant: "jan" },
                { team: "Team A", scorer: "jan", assistant: "adam", own_goal: true }
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
        expect(result.errors).to include("Match 1 goal 1 needs a team")
        expect(result.errors).to include("Match 1 goal 1 needs a scorer")
        expect(result.errors).to include("Match 1 goal 2 references unknown team: Missing")
        expect(result.errors).to include("adam is not listed in Team B for match 1")
        expect(result.errors).to include("ghost is not listed in Team B for match 1")
        expect(result.errors).to include("Assistant cannot be the scorer for jan")
        expect(result.errors).to include("Own goal for jan cannot have an assist")
        expect(MatchDay.count).to eq(0)
      end

      it "rejects a captain who is not on the team roster" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          teams: [
            { name: "Team A", players: [ "adam" ], captain: "jan" },
            { name: "Team B", players: [ "jan" ], captain: "jan" }
          ],
          goals: [
            { team: "Team A", scorer: "adam" }
          ]
        }

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("jan must be listed in Team A as a player")
        expect(MatchDay.count).to eq(0)
      end

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

      it "returns false when match day creation fails" do
        season = create(:season)
        player = create(:player, nickname: "adam", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          teams: [
            { name: "Team A", players: [ "adam" ] },
            { name: "Team B", players: [ "adam" ] }
          ],
          goals: [
            { team: "Team A", scorer: "adam" }
          ]
        }
        allow(CreateMatchDay).to receive(:call).and_return(false)

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to be_empty
        expect(MatchDay.count).to eq(0)
        expect(player.reload).to be_present
      end

      it "returns an error when starting an imported match fails" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          teams: [
            { name: "Team A", players: [ "adam" ] },
            { name: "Team B", players: [ "jan" ] }
          ],
          goals: [
            { team: "Team A", scorer: "adam" }
          ]
        }
        allow(Matches::StartMatch).to receive(:call).and_return(false)

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("Could not start imported match 1")
        expect(MatchDay.count).to eq(0)
      end

      it "returns an error when adding an imported goal fails" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          teams: [
            { name: "Team A", players: [ "adam" ] },
            { name: "Team B", players: [ "jan" ] }
          ],
          goals: [
            { team: "Team A", scorer: "adam" }
          ]
        }
        allow(Matches::StartMatch).to receive(:call).and_return(true)
        allow(Matches::AddGoal).to receive(:call).and_return(false)

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("Could not add goal 1 for match 1")
        expect(MatchDay.count).to eq(0)
      end

      it "returns an error when finishing an imported match fails" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          finished_at: "2026-06-19 19:40",
          teams: [
            { name: "Team A", players: [ "adam" ] },
            { name: "Team B", players: [ "jan" ] }
          ],
          goals: [
            { team: "Team A", scorer: "adam" }
          ]
        }
        allow(Matches::StartMatch).to receive(:call).and_return(true)
        allow(Matches::AddGoal).to receive(:call).and_return(true)
        allow(Matches::FinishMatch).to receive(:call).and_return(false)

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("Could not finish imported match 1")
        expect(MatchDay.count).to eq(0)
      end

      it "returns record validation errors from unexpected persistence failures" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          teams: [
            { name: "Team A", players: [ "adam" ] },
            { name: "Team B", players: [ "jan" ] }
          ],
          goals: [
            { team: "Team A", scorer: "adam" }
          ]
        }
        invalid_match_day = MatchDay.new
        invalid_match_day.errors.add(:base, "unexpected validation failure")
        allow(MatchDay).to receive(:transaction).and_raise(ActiveRecord::RecordInvalid.new(invalid_match_day))

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("unexpected validation failure")
      end

      it "returns argument errors from unexpected import failures" do
        season = create(:season)
        create(:player, nickname: "adam", approval_status: "approved", active: true)
        create(:player, name: "Jan", nickname: "jan", phone: "+48999999998", approval_status: "approved", active: true)
        payload = {
          played_on: "2026-06-19",
          teams: [
            { name: "Team A", players: [ "adam" ] },
            { name: "Team B", players: [ "jan" ] }
          ],
          goals: [
            { team: "Team A", scorer: "adam" }
          ]
        }
        allow(MatchDay).to receive(:transaction).and_raise(ArgumentError, "bad import")

        result = described_class.call(
          payload:,
          season:,
          available_players: Player.approved.active.order(:name)
        )

        expect(result).not_to be_success
        expect(result.errors).to include("bad import")
      end
    end
  end
end
