class ImportMatchDay20261108 < ActiveRecord::Migration[8.1]
  PLAYED_ON = Date.new(2026, 11, 8)
  PAYLOAD = JSON.parse(<<~JSON, symbolize_names: true).freeze
    {
      "season_id": 1,
      "played_on": "2026-11-08",
      "original_teams": [
        {
          "name": "Team Wicu",
          "captain": "Wicu",
          "players": [
            "Wicu",
            "Rafał (Bramkarz)",
            "Piotrek (Cash)",
            "Kamil (Marcelo)",
            "Kamil (Barcelona)",
            "Baca",
            "Krzychu (Witia)",
            "Patryk (od Witia)",
            "Dawid (Nowy)"
          ]
        },
        {
          "name": "Team Dima",
          "captain": "Dima",
          "players": [
            "Dima",
            "Płaczek",
            "Max",
            "Mirek",
            "Adi",
            "Dominik",
            "Sławek",
            "Daniel (Żaba)",
            "Arek (Nowy)"
          ]
        }
      ],
      "matches": [
        {
          "started_at": "2026-11-08T10:14:40.920+01:00",
          "finished_at": "2026-11-08T11:34:22.310+01:00",
          "all_roster_players_on_pitch": false,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Rafał (Bramkarz)",
                "Piotrek (Cash)",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Baca",
                "Krzychu (Witia)",
                "Patryk (od Witia)",
                "Dawid (Nowy)"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Płaczek",
                "Max",
                "Mirek",
                "Adi",
                "Dominik",
                "Sławek",
                "Daniel (Żaba)",
                "Arek (Nowy)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Wicu",
              "scorer": "Kamil (Barcelona)",
              "assistant": "Patryk (od Witia)",
              "scored_at": "2026-11-08T10:16:50.070+01:00",
              "own_goal": false
            },
            {
              "team": "Team Wicu",
              "scorer": "Kamil (Marcelo)",
              "assistant": "Krzychu (Witia)",
              "scored_at": "2026-11-08T10:32:18.230+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Sławek",
              "assistant": "Płaczek",
              "scored_at": "2026-11-08T10:35:28.920+01:00",
              "own_goal": false
            },
            {
              "team": "Team Wicu",
              "scorer": "Wicu",
              "assistant": "Kamil (Marcelo)",
              "scored_at": "2026-11-08T10:45:32.180+01:00",
              "own_goal": false
            },
            {
              "team": "Team Wicu",
              "scorer": "Kamil (Marcelo)",
              "assistant": null,
              "scored_at": "2026-11-08T10:46:21.920+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Adi",
              "assistant": null,
              "scored_at": "2026-11-08T11:00:03.720+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Dima",
              "assistant": null,
              "scored_at": "2026-11-08T11:08:32.140+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Płaczek",
              "assistant": null,
              "scored_at": "2026-11-08T11:11:12.240+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Sławek",
              "assistant": "Płaczek",
              "scored_at": "2026-11-08T11:34:20.630+01:00",
              "own_goal": false
            }
          ]
        },
        {
          "started_at": "2026-11-08T11:37:48.740+01:00",
          "finished_at": "2026-11-08T12:08:19.500+01:00",
          "all_roster_players_on_pitch": false,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Rafał (Bramkarz)",
                "Piotrek (Cash)",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Baca",
                "Krzychu (Witia)",
                "Patryk (od Witia)",
                "Dawid (Nowy)"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Płaczek",
                "Max",
                "Adi",
                "Dominik",
                "Sławek",
                "Daniel (Żaba)",
                "Arek (Nowy)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Dima",
              "scorer": "Adi",
              "assistant": "Sławek",
              "scored_at": "2026-11-08T11:41:10.610+01:00",
              "own_goal": false
            },
            {
              "team": "Team Wicu",
              "scorer": "Piotrek (Cash)",
              "assistant": null,
              "scored_at": "2026-11-08T11:54:49.360+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Adi",
              "assistant": "Arek (Nowy)",
              "scored_at": "2026-11-08T11:56:33.190+01:00",
              "own_goal": false
            },
            {
              "team": "Team Wicu",
              "scorer": "Wicu",
              "assistant": null,
              "scored_at": "2026-11-08T12:00:29.480+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Max",
              "assistant": "Dominik",
              "scored_at": "2026-11-08T12:02:26.590+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Max",
              "assistant": "Dima",
              "scored_at": "2026-11-08T12:06:11.700+01:00",
              "own_goal": false
            },
            {
              "team": "Team Wicu",
              "scorer": "Kamil (Marcelo)",
              "assistant": null,
              "scored_at": "2026-11-08T12:06:54.680+01:00",
              "own_goal": false
            },
            {
              "team": "Team Dima",
              "scorer": "Dima",
              "assistant": null,
              "scored_at": "2026-11-08T12:08:15.640+01:00",
              "own_goal": false
            }
          ]
        }
      ]
    }
  JSON

  def up
    day = MatchDay.find_by(played_on: PLAYED_ON)
    if day
      verify_day!(day)
      return
    end

    season = Season.find(PAYLOAD.fetch(:season_id))
    raise "Unexpected season for 8 November" unless season.name == "Lato 2026" && season.status == Season::STATUS_ACTIVE

    rename_krzychu!
    [ "Patryk (od Witia)", "Arek (Nowy)", "Dawid (Nowy)" ].each do |name|
      Player.find_or_create_by!(nickname: name) do |player|
        player.assign_attributes(name:, description: "Uczestnik dnia meczowego 08.11.2026.", role_code: "ANY",
          approval_status: "approved", active: true)
      end
    end

    result = MatchDays::ImportFromPayload.call(payload: PAYLOAD, season:, available_players: Player.active_public)
    raise "Match day import failed: #{result.errors.to_sentence}" unless result.success?

    free_kick = result.matches.first.match_goals.active.find_by!(home_score_after: 4, away_score_after: 4)
    raise "Unexpected scorer for the equalizer" unless free_kick.scorer.name == "Płaczek"

    free_kick.update!(set_piece: :free_kick)
    verify_day!(result.match_day.reload)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_krzychu!
    player = Player.find(32)
    unless [ "Krzysiek (Nowy)", "Krzychu (Witia)" ].include?(player.name)
      raise "Unexpected player record for Krzychu"
    end

    player.update!(name: "Krzychu (Witia)", nickname: "Krzychu (Witia)")
  end

  def verify_day!(day)
    matches = day.matches.order(:started_at, :id).to_a
    scores = matches.map { |match| [ match.home_score, match.away_score ] }
    goals = matches.flat_map { |match| match.match_goals.active.to_a }
    unless day.status == "finished" && day.season_id == PAYLOAD.fetch(:season_id) &&
      day.match_day_players.count == 18 && matches.all?(&:finished?) &&
      scores == [ [ 4, 5 ], [ 3, 5 ] ] && goals.size == 17 &&
      goals.count { |goal| goal.assistant_team_player_id.present? } == 9 &&
      goals.any? { |goal| goal.free_kick? && goal.scorer.name == "Płaczek" }
      raise "Unexpected saved data for 8 November"
    end
  end
end
