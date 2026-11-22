class ImportMatchDay20261122 < ActiveRecord::Migration[8.1]
  PLAYED_ON = Date.new(2026, 11, 22)
  PAYLOAD = JSON.parse(<<~JSON, symbolize_names: true).freeze
    {
      "season_id": 1,
      "played_on": "2026-11-22",
      "original_teams": [
        {
          "name": "Team Rafał",
          "captain": "Rafał (Bramkarz)",
          "players": [
            "Rafał (Bramkarz)",
            "Wicu",
            "Sławek",
            "Baca",
            "Daniel (Żaba)",
            "Dominik",
            "Przemo",
            "Franklin",
            "Grzegorz (z piątku)"
          ]
        },
        {
          "name": "Team Piotrek",
          "captain": "Piotrek (Bramkarz)",
          "players": [
            "Płaczek",
            "Darek (Koniu)",
            "Marcin (Milik)",
            "Barcelona",
            "Kamil (Marcelo)",
            "Adi",
            "Max",
            "Dawid (Nowy)",
            "Krzychu (Witia)",
            "Piotrek (Bramkarz)"
          ]
        }
      ],
      "matches": [
        {
          "started_at": "2026-11-22T10:11:37.950000+01:00",
          "finished_at": "2026-11-22T10:47:04.560000+01:00",
          "all_roster_players_on_pitch": false,
          "teams": [
            {
              "name": "Team Rafał",
              "captain": "Rafał (Bramkarz)",
              "players": [
                "Rafał (Bramkarz)",
                "Wicu",
                "Sławek",
                "Baca",
                "Daniel (Żaba)",
                "Dominik",
                "Przemo",
                "Franklin",
                "Grzegorz (z piątku)"
              ]
            },
            {
              "name": "Team Piotrek",
              "captain": "Piotrek (Bramkarz)",
              "players": [
                "Płaczek",
                "Darek (Koniu)",
                "Marcin (Milik)",
                "Barcelona",
                "Kamil (Marcelo)",
                "Adi",
                "Max",
                "Dawid (Nowy)",
                "Krzychu (Witia)",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Piotrek",
              "scorer": "Dominik",
              "scored_at": "2026-11-22T10:21:33.670000+01:00",
              "own_goal": true
            },
            {
              "team": "Team Rafał",
              "scorer": "Wicu",
              "scored_at": "2026-11-22T10:22:44.620000+01:00",
              "assistant": "Sławek"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Płaczek",
              "scored_at": "2026-11-22T10:29:08.480000+01:00"
            },
            {
              "team": "Team Rafał",
              "scorer": "Sławek",
              "scored_at": "2026-11-22T10:31:22.740000+01:00",
              "assistant": "Franklin"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Płaczek",
              "scored_at": "2026-11-22T10:31:52.090000+01:00"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Płaczek",
              "scored_at": "2026-11-22T10:36:31.650+01:00",
              "set_piece": "penalty"
            },
            {
              "team": "Team Rafał",
              "scorer": "Baca",
              "scored_at": "2026-11-22T10:45:34.150000+01:00",
              "assistant": "Przemo"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Darek (Koniu)",
              "scored_at": "2026-11-22T10:47:02.780000+01:00",
              "assistant": "Marcin (Milik)"
            }
          ]
        },
        {
          "started_at": "2026-11-22T10:49:16.080000+01:00",
          "finished_at": "2026-11-22T11:23:48.030000+01:00",
          "all_roster_players_on_pitch": false,
          "teams": [
            {
              "name": "Team Rafał",
              "captain": "Rafał (Bramkarz)",
              "players": [
                "Rafał (Bramkarz)",
                "Wicu",
                "Sławek",
                "Baca",
                "Daniel (Żaba)",
                "Dominik",
                "Przemo",
                "Franklin",
                "Grzegorz (z piątku)"
              ]
            },
            {
              "name": "Team Piotrek",
              "captain": "Piotrek (Bramkarz)",
              "players": [
                "Płaczek",
                "Darek (Koniu)",
                "Marcin (Milik)",
                "Barcelona",
                "Kamil (Marcelo)",
                "Adi",
                "Max",
                "Dawid (Nowy)",
                "Krzychu (Witia)",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Rafał",
              "scorer": "Daniel (Żaba)",
              "scored_at": "2026-11-22T10:50:49.410000+01:00",
              "assistant": "Przemo"
            },
            {
              "team": "Team Rafał",
              "scorer": "Baca",
              "scored_at": "2026-11-22T10:51:24.660000+01:00",
              "assistant": "Franklin"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Marcin (Milik)",
              "scored_at": "2026-11-22T10:53:36.060000+01:00",
              "assistant": "Płaczek"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Max",
              "scored_at": "2026-11-22T11:04:34.720000+01:00"
            },
            {
              "team": "Team Rafał",
              "scorer": "Baca",
              "scored_at": "2026-11-22T11:07:35.720000+01:00"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Darek (Koniu)",
              "scored_at": "2026-11-22T11:10:56.670000+01:00",
              "assistant": "Max"
            },
            {
              "team": "Team Rafał",
              "scorer": "Sławek",
              "scored_at": "2026-11-22T11:12:44.060000+01:00",
              "assistant": "Wicu"
            },
            {
              "team": "Team Rafał",
              "scorer": "Baca",
              "scored_at": "2026-11-22T11:23:45.810000+01:00",
              "assistant": "Daniel (Żaba)"
            }
          ]
        },
        {
          "started_at": "2026-11-22T11:27:53.270000+01:00",
          "finished_at": "2026-11-22T11:45:49.710000+01:00",
          "all_roster_players_on_pitch": false,
          "teams": [
            {
              "name": "Team Rafał",
              "captain": "Rafał (Bramkarz)",
              "players": [
                "Rafał (Bramkarz)",
                "Wicu",
                "Sławek",
                "Baca",
                "Daniel (Żaba)",
                "Dominik",
                "Przemo",
                "Franklin",
                "Grzegorz (z piątku)"
              ]
            },
            {
              "name": "Team Piotrek",
              "captain": "Piotrek (Bramkarz)",
              "players": [
                "Płaczek",
                "Darek (Koniu)",
                "Marcin (Milik)",
                "Barcelona",
                "Kamil (Marcelo)",
                "Adi",
                "Max",
                "Dawid (Nowy)",
                "Krzychu (Witia)",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Rafał",
              "scorer": "Baca",
              "scored_at": "2026-11-22T11:29:18.430000+01:00",
              "assistant": "Wicu"
            },
            {
              "team": "Team Rafał",
              "scorer": "Baca",
              "scored_at": "2026-11-22T11:32:59.300000+01:00",
              "assistant": "Sławek"
            },
            {
              "team": "Team Rafał",
              "scorer": "Daniel (Żaba)",
              "scored_at": "2026-11-22T11:34:40.790000+01:00",
              "assistant": "Przemo"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Krzychu (Witia)",
              "scored_at": "2026-11-22T11:37:53.550000+01:00",
              "assistant": "Płaczek"
            },
            {
              "team": "Team Rafał",
              "scorer": "Przemo",
              "scored_at": "2026-11-22T11:40:35.530000+01:00",
              "assistant": "Daniel (Żaba)"
            },
            {
              "team": "Team Piotrek",
              "scorer": "Max",
              "scored_at": "2026-11-22T11:44:03.260000+01:00",
              "assistant": "Płaczek"
            },
            {
              "team": "Team Rafał",
              "scorer": "Daniel (Żaba)",
              "scored_at": "2026-11-22T11:45:45.300000+01:00",
              "assistant": "Baca"
            }
          ]
        },
        {
          "started_at": "2026-11-22T11:47:29.290000+01:00",
          "finished_at": "2026-11-22T12:03:21.720000+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Rafał",
              "captain": "Rafał (Bramkarz)",
              "players": [
                "Rafał (Bramkarz)",
                "Wicu",
                "Sławek",
                "Baca",
                "Daniel (Żaba)",
                "Dominik",
                "Przemo",
                "Franklin",
                "Grzegorz (z piątku)"
              ]
            },
            {
              "name": "Team Piotrek",
              "captain": "Piotrek (Bramkarz)",
              "players": [
                "Płaczek",
                "Darek (Koniu)",
                "Marcin (Milik)",
                "Barcelona",
                "Adi",
                "Max",
                "Dawid (Nowy)",
                "Krzychu (Witia)",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Rafał",
              "scorer": "Dominik",
              "scored_at": "2026-11-22T11:47:59.580000+01:00"
            },
            {
              "team": "Team Rafał",
              "scorer": "Sławek",
              "scored_at": "2026-11-22T11:58:11.420000+01:00",
              "assistant": "Wicu"
            },
            {
              "team": "Team Rafał",
              "scorer": "Franklin",
              "scored_at": "2026-11-22T11:59:23.320000+01:00",
              "assistant": "Sławek"
            },
            {
              "team": "Team Rafał",
              "scorer": "Wicu",
              "scored_at": "2026-11-22T12:00:29.670000+01:00",
              "assistant": "Baca"
            },
            {
              "team": "Team Rafał",
              "scorer": "Daniel (Żaba)",
              "scored_at": "2026-11-22T12:03:12.160000+01:00",
              "assistant": "Sławek"
            }
          ]
        }
      ]
    }
  JSON

  def up
    days = MatchDay.where(played_on: PLAYED_ON).to_a
    raise "Multiple match days for 22 November" if days.size > 1

    if days.any?
      verify_day!(days.first)
      return
    end

    season = Season.find(PAYLOAD.fetch(:season_id))
    unless season.name == "Lato 2026" && season.status == Season::STATUS_ACTIVE
      raise "Unexpected active season for 22 November"
    end

    result = MatchDays::ImportFromPayload.call(payload: PAYLOAD, season:, available_players: Player.approved.active)
    raise "Match day import failed: #{result.errors.to_sentence}" unless result.success?

    verify_day!(result.match_day.reload)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def verify_day!(day)
    matches = day.matches.order(:started_at, :id).to_a
    expected = PAYLOAD.fetch(:matches)
    unless day.status == "finished" && day.season_id == PAYLOAD.fetch(:season_id) &&
      day.match_day_players.count == 19 && matches.size == expected.size
      raise "Unexpected match day for 22 November"
    end

    matches.zip(expected).each_with_index { |(match, data), index| verify_match!(match, data, index + 1) }
  end

  def verify_match!(match, data, number)
    unless match.finished? && match.elo_processed_at.present? &&
      match.all_roster_players_on_pitch? == data.fetch(:all_roster_players_on_pitch) &&
      match.started_at == Time.iso8601(data.fetch(:started_at)) &&
      match.finished_at == Time.iso8601(data.fetch(:finished_at))
      raise "Unexpected match #{number} status or time"
    end

    [ match.home_team, match.away_team ].zip(data.fetch(:teams)).each do |team, expected|
      unless team.name == expected.fetch(:name) && team.captain&.nickname == expected.fetch(:captain) &&
        team.players.pluck(:nickname).sort == expected.fetch(:players).sort
        raise "Unexpected lineup in match #{number}"
      end
    end

    goals = match.match_goals.active.includes(:scoring_team, scorer_team_player: :player,
      assistant_team_player: :player).order(:scored_at, :id).to_a
    actual = goals.map do |goal|
      [ goal.scoring_team.name, goal.scorer_team_player.player.nickname, goal.assistant_team_player&.player&.nickname,
        goal.scored_at, goal.own_goal?, goal.set_piece ]
    end
    expected = data.fetch(:goals).map do |goal|
      [ goal.fetch(:team), goal.fetch(:scorer), goal[:assistant], Time.iso8601(goal.fetch(:scored_at)),
        goal.fetch(:own_goal, false), goal[:set_piece] ]
    end.sort_by { |goal| goal[3] }
    raise "Unexpected goals in match #{number}" unless actual == expected

    score = [ match.home_team.name, match.away_team.name ].map do |name|
      data.fetch(:goals).count { |goal| goal.fetch(:team) == name }
    end
    raise "Unexpected score in match #{number}" unless [ match.home_score, match.away_score ] == score
  end
end
