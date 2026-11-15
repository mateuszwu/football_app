class ImportMatchDay20261115 < ActiveRecord::Migration[8.1]
  PLAYED_ON = Date.new(2026, 11, 15)
  PAYLOAD = JSON.parse(<<~JSON, symbolize_names: true).freeze
    {
      "season_id": 1,
      "played_on": "2026-11-15",
      "original_teams": [
        {
          "name": "Team Wicu",
          "captain": "Wicu",
          "players": [
            "Wicu",
            "Dominik",
            "Marcin (Milik)",
            "Max",
            "Adi",
            "Franklin",
            "Piotrek (Bramkarz)"
          ]
        },
        {
          "name": "Team Dima",
          "captain": "Dima",
          "players": [
            "Dima",
            "Zajas",
            "Dawid (Nowy)",
            "Sławek",
            "Kamil (Marcelo)",
            "Kamil (Barcelona)"
          ]
        },
        {
          "name": "Team Cash",
          "captain": "Piotrek (Cash)",
          "players": [
            "Piotrek (Cash)",
            "Płaczek",
            "Baca",
            "Daniel (Żaba)",
            "Krzychu (Witia)",
            "Przemo"
          ]
        }
      ],
      "matches": [
        {
          "started_at": "2026-11-15T10:14:11.160+01:00",
          "finished_at": "2026-11-15T10:27:37.640+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Dominik",
                "Marcin (Milik)",
                "Max",
                "Adi",
                "Franklin",
                "Piotrek (Bramkarz)"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Zajas",
                "Dawid (Nowy)",
                "Sławek",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Baca"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Wicu",
              "scorer": "Marcin (Milik)",
              "scored_at": "2026-11-15T10:20:32.260+01:00",
              "assistant": "Franklin"
            },
            {
              "team": "Team Wicu",
              "scorer": "Wicu",
              "scored_at": "2026-11-15T10:24:25.770+01:00",
              "assistant": "Max"
            }
          ]
        },
        {
          "started_at": "2026-11-15T10:28:05.980+01:00",
          "finished_at": "2026-11-15T10:38:24.650+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Dominik",
                "Marcin (Milik)",
                "Max",
                "Adi",
                "Franklin",
                "Piotrek (Bramkarz)"
              ]
            },
            {
              "name": "Team Cash",
              "captain": "Piotrek (Cash)",
              "players": [
                "Piotrek (Cash)",
                "Płaczek",
                "Baca",
                "Daniel (Żaba)",
                "Krzychu (Witia)",
                "Przemo",
                "Dima"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Wicu",
              "scorer": "Max",
              "scored_at": "2026-11-15T10:32:52.360+01:00",
              "assistant": "Wicu"
            },
            {
              "team": "Team Wicu",
              "scorer": "Marcin (Milik)",
              "scored_at": "2026-11-15T10:35:37.020+01:00"
            }
          ]
        },
        {
          "started_at": "2026-11-15T10:38:52.190+01:00",
          "finished_at": "2026-11-15T10:49:26.460+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Zajas",
                "Dawid (Nowy)",
                "Sławek",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Piotrek (Bramkarz)"
              ]
            },
            {
              "name": "Team Cash",
              "captain": "Piotrek (Cash)",
              "players": [
                "Piotrek (Cash)",
                "Płaczek",
                "Baca",
                "Daniel (Żaba)",
                "Krzychu (Witia)",
                "Przemo",
                "Wicu"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Dima",
              "scorer": "Dawid (Nowy)",
              "scored_at": "2026-11-15T10:43:27.040+01:00",
              "assistant": "Zajas"
            },
            {
              "team": "Team Dima",
              "scorer": "Kamil (Marcelo)",
              "scored_at": "2026-11-15T10:45:30.270+01:00",
              "assistant": "Dima"
            },
            {
              "team": "Team Cash",
              "scorer": "Płaczek",
              "scored_at": "2026-11-15T10:46:55.570+01:00"
            }
          ]
        },
        {
          "started_at": "2026-11-15T10:49:38.650+01:00",
          "finished_at": "2026-11-15T11:00:05.770+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Dominik",
                "Marcin (Milik)",
                "Max",
                "Adi",
                "Franklin",
                "Baca"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Zajas",
                "Dawid (Nowy)",
                "Sławek",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Wicu",
              "scorer": "Marcin (Milik)",
              "scored_at": "2026-11-15T10:52:11.890+01:00",
              "assistant": "Dominik"
            },
            {
              "team": "Team Wicu",
              "scorer": "Max",
              "scored_at": "2026-11-15T10:55:19.580+01:00",
              "assistant": "Marcin (Milik)"
            },
            {
              "team": "Team Dima",
              "scorer": "Sławek",
              "scored_at": "2026-11-15T10:57:11.590+01:00",
              "assistant": "Zajas"
            }
          ]
        },
        {
          "started_at": "2026-11-15T11:00:34.600+01:00",
          "finished_at": "2026-11-15T11:10:50.310+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Dominik",
                "Marcin (Milik)",
                "Max",
                "Adi",
                "Franklin",
                "Dima"
              ]
            },
            {
              "name": "Team Cash",
              "captain": "Piotrek (Cash)",
              "players": [
                "Piotrek (Cash)",
                "Płaczek",
                "Baca",
                "Daniel (Żaba)",
                "Krzychu (Witia)",
                "Przemo",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": []
        },
        {
          "started_at": "2026-11-15T11:11:24.370+01:00",
          "finished_at": "2026-11-15T11:22:17.650+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Cash",
              "captain": "Piotrek (Cash)",
              "players": [
                "Piotrek (Cash)",
                "Płaczek",
                "Baca",
                "Daniel (Żaba)",
                "Krzychu (Witia)",
                "Przemo",
                "Piotrek (Bramkarz)"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Zajas",
                "Dawid (Nowy)",
                "Sławek",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Franklin"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Cash",
              "scorer": "Płaczek",
              "scored_at": "2026-11-15T11:12:01.350+01:00",
              "assistant": "Baca"
            },
            {
              "team": "Team Dima",
              "scorer": "Dima",
              "scored_at": "2026-11-15T11:19:29.930+01:00"
            },
            {
              "team": "Team Dima",
              "scorer": "Sławek",
              "scored_at": "2026-11-15T11:20:27.860+01:00",
              "assistant": "Dima"
            },
            {
              "team": "Team Cash",
              "scorer": "Płaczek",
              "scored_at": "2026-11-15T11:21:16.540+01:00"
            }
          ]
        },
        {
          "started_at": "2026-11-15T11:22:28.020+01:00",
          "finished_at": "2026-11-15T11:32:46.530+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Dominik",
                "Marcin (Milik)",
                "Max",
                "Adi",
                "Franklin",
                "Baca"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Zajas",
                "Dawid (Nowy)",
                "Sławek",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Dima",
              "scorer": "Zajas",
              "scored_at": "2026-11-15T11:24:25.160+01:00",
              "assistant": "Kamil (Marcelo)"
            },
            {
              "team": "Team Dima",
              "scorer": "Dima",
              "scored_at": "2026-11-15T11:29:38.370+01:00"
            },
            {
              "team": "Team Dima",
              "scorer": "Kamil (Barcelona)",
              "scored_at": "2026-11-15T11:32:22.750+01:00",
              "assistant": "Zajas"
            }
          ]
        },
        {
          "started_at": "2026-11-15T11:33:29.310+01:00",
          "finished_at": "2026-11-15T11:43:38.140+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Cash",
              "captain": "Piotrek (Cash)",
              "players": [
                "Piotrek (Cash)",
                "Płaczek",
                "Baca",
                "Daniel (Żaba)",
                "Krzychu (Witia)",
                "Przemo",
                "Piotrek (Bramkarz)"
              ]
            },
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Dominik",
                "Marcin (Milik)",
                "Max",
                "Adi",
                "Franklin",
                "Dima"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Cash",
              "scorer": "Daniel (Żaba)",
              "scored_at": "2026-11-15T11:38:16.300+01:00"
            },
            {
              "team": "Team Cash",
              "scorer": "Płaczek",
              "scored_at": "2026-11-15T11:40:49.700+01:00"
            }
          ]
        },
        {
          "started_at": "2026-11-15T11:44:30.970+01:00",
          "finished_at": "2026-11-15T11:54:43.960+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Cash",
              "captain": "Piotrek (Cash)",
              "players": [
                "Piotrek (Cash)",
                "Płaczek",
                "Baca",
                "Daniel (Żaba)",
                "Krzychu (Witia)",
                "Przemo",
                "Piotrek (Bramkarz)"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Zajas",
                "Dawid (Nowy)",
                "Sławek",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Marcin (Milik)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Dima",
              "scorer": "Dima",
              "scored_at": "2026-11-15T11:44:47.750+01:00",
              "assistant": "Zajas"
            },
            {
              "team": "Team Cash",
              "scorer": "Krzychu (Witia)",
              "scored_at": "2026-11-15T11:47:52.630+01:00",
              "assistant": "Płaczek"
            },
            {
              "team": "Team Cash",
              "scorer": "Daniel (Żaba)",
              "scored_at": "2026-11-15T11:48:32.550+01:00",
              "assistant": "Płaczek"
            },
            {
              "team": "Team Cash",
              "scorer": "Płaczek",
              "scored_at": "2026-11-15T11:49:51.560+01:00"
            },
            {
              "team": "Team Cash",
              "scorer": "Płaczek",
              "scored_at": "2026-11-15T11:50:32.700+01:00",
              "assistant": "Piotrek (Cash)"
            },
            {
              "team": "Team Dima",
              "scorer": "Zajas",
              "scored_at": "2026-11-15T11:51:14.460+01:00",
              "assistant": "Dima"
            },
            {
              "team": "Team Dima",
              "scorer": "Sławek",
              "scored_at": "2026-11-15T11:51:54.450+01:00"
            },
            {
              "team": "Team Cash",
              "scorer": "Krzychu (Witia)",
              "scored_at": "2026-11-15T11:54:40.270+01:00",
              "assistant": "Piotrek (Cash)"
            }
          ]
        },
        {
          "started_at": "2026-11-15T11:55:16.300+01:00",
          "finished_at": "2026-11-15T12:05:48.300+01:00",
          "all_roster_players_on_pitch": true,
          "teams": [
            {
              "name": "Team Wicu",
              "captain": "Wicu",
              "players": [
                "Wicu",
                "Dominik",
                "Marcin (Milik)",
                "Max",
                "Adi",
                "Franklin",
                "Baca"
              ]
            },
            {
              "name": "Team Dima",
              "captain": "Dima",
              "players": [
                "Dima",
                "Zajas",
                "Dawid (Nowy)",
                "Sławek",
                "Kamil (Marcelo)",
                "Kamil (Barcelona)",
                "Piotrek (Bramkarz)"
              ]
            }
          ],
          "goals": [
            {
              "team": "Team Wicu",
              "scorer": "Wicu",
              "scored_at": "2026-11-15T11:56:36.660+01:00",
              "assistant": "Marcin (Milik)"
            },
            {
              "team": "Team Dima",
              "scorer": "Kamil (Barcelona)",
              "scored_at": "2026-11-15T11:58:37.680+01:00",
              "assistant": "Zajas"
            },
            {
              "team": "Team Wicu",
              "scorer": "Max",
              "scored_at": "2026-11-15T12:00:55.180+01:00",
              "assistant": "Franklin"
            },
            {
              "team": "Team Dima",
              "scorer": "Kamil (Barcelona)",
              "scored_at": "2026-11-15T12:05:00.500+01:00"
            },
            {
              "team": "Team Wicu",
              "scorer": "Franklin",
              "scored_at": "2026-11-15T12:05:36.920+01:00",
              "assistant": "Marcin (Milik)"
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
    raise "Unexpected active season for 15 November" unless season.name == "Lato 2026" && season.status == Season::STATUS_ACTIVE

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
    raise "Unexpected match day for 15 November" unless day.status == "finished" &&
      day.season_id == PAYLOAD.fetch(:season_id) && day.match_day_players.count == 19 && matches.size == expected.size

    matches.zip(expected).each_with_index do |(match, data), index|
      verify_match!(match, data, index + 1)
    end
  end

  def verify_match!(match, data, number)
    raise "Unexpected match #{number} status or time" unless match.finished? && match.all_roster_players_on_pitch? &&
      match.started_at.to_i == Time.iso8601(data.fetch(:started_at)).to_i &&
      match.finished_at.to_i == Time.iso8601(data.fetch(:finished_at)).to_i

    [ match.home_team, match.away_team ].zip(data.fetch(:teams)).each do |team, expected|
      next if team.name == expected.fetch(:name) && team.players.pluck(:name).sort == expected.fetch(:players).sort

      raise "Unexpected lineup in match #{number}"
    end

    actual = match.match_goals.active.includes(:scoring_team, scorer_team_player: :player,
      assistant_team_player: :player).order(:scored_at, :id).map do |goal|
      [ goal.scoring_team.name, goal.scorer_team_player.player.name, goal.assistant_team_player&.player&.name,
        goal.scored_at.to_i ]
    end
    expected = data.fetch(:goals).map do |goal|
      [ goal.fetch(:team), goal.fetch(:scorer), goal[:assistant], Time.iso8601(goal.fetch(:scored_at)).to_i ]
    end.sort_by(&:last)
    raise "Unexpected goals in match #{number}" unless actual == expected
  end
end
