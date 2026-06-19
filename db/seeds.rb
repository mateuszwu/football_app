# This file creates a small, repeatable demo dataset for local development.
# It is intentionally scoped to the demo season and demo player phones so reruns
# refresh sample data without touching real records.

DEMO_SEASON_NAME = "Demo Summer 2026".freeze
DEMO_PLAYERS = [
  { name: "Adam Demo", nickname: "seed-adam", phone: "+48900000001", role_code: "ATT" },
  { name: "Jan Demo", nickname: "seed-jan", phone: "+48900000002", role_code: "MID" },
  { name: "Marek Demo", nickname: "seed-marek", phone: "+48900000003", role_code: "DEF" },
  { name: "Piotr Demo", nickname: "seed-piotr", phone: "+48900000004", role_code: "GK" },
  { name: "Kamil Demo", nickname: "seed-kamil", phone: "+48900000005", role_code: "ATT" },
  { name: "Tomek Demo", nickname: "seed-tomek", phone: "+48900000006", role_code: "MID" },
  { name: "Bartek Demo", nickname: "seed-bartek", phone: "+48900000007", role_code: "DEF" },
  { name: "Lukasz Demo", nickname: "seed-lukasz", phone: "+48900000008", role_code: "ANY" }
].freeze

def demo_vote_plan(players)
  {
    "seed-adam" => [ "seed-jan", "seed-marek" ],
    "seed-jan" => [ "seed-adam", "seed-marek" ],
    "seed-marek" => [ "seed-adam", "seed-piotr" ],
    "seed-piotr" => [ "seed-jan", "seed-marek" ],
    "seed-kamil" => [ "seed-adam", "seed-bartek" ],
    "seed-tomek" => [ "seed-kamil", "seed-bartek" ],
    "seed-bartek" => [ "seed-kamil", "seed-marek" ],
    "seed-lukasz" => [ "seed-tomek", "seed-bartek" ]
  }.transform_values { |(mvp_nickname, def_nickname)| [ players.fetch(mvp_nickname), players.fetch(def_nickname) ] }
end

def submit_demo_votes!(match_day:, players:)
  vote_plan = demo_vote_plan(players)

  match_day.match_day_players.includes(:player, :match_day_vote_token).find_each do |match_day_player|
    mvp_player, def_player = vote_plan.fetch(match_day_player.player.nickname)
    Voting::SubmitVote.call(
      match_day_vote_token: match_day_player.match_day_vote_token,
      mvp_player_id: mvp_player.id,
      def_player_id: def_player.id
    )
  end
end

def import_demo_match_day!(season:, payload:)
  result = MatchDays::ImportFromPayload.call(
    payload: payload.merge(season_id: season.id),
    season:,
    available_players: Player.approved.active.order(:name)
  )

  raise "Could not seed #{payload.fetch(:played_on)}: #{result.errors.to_sentence}" unless result.success?

  result.matches.each do |match|
    Ratings::ProcessMatchElo.call(match:) if match.finished?
  end

  result.match_day
end

if (demo_season = Season.find_by(name: DEMO_SEASON_NAME))
  demo_match_day_ids = demo_season.match_days.ids
  MatchGoal.joins(:match).where(matches: { match_day_id: demo_match_day_ids }).destroy_all
  Match.where(match_day_id: demo_match_day_ids).destroy_all
  demo_season.destroy!
end
Player.where(phone: DEMO_PLAYERS.map { |player| player.fetch(:phone) }).destroy_all

season = Season.create!(
  name: DEMO_SEASON_NAME,
  starts_on: Date.new(2026, 6, 1),
  ends_on: Date.new(2026, 8, 31),
  status: Season::STATUS_ACTIVE,
  initial_elo: 1000,
  elo_k_factor: 32,
  elo_k_value: BigDecimal("18.0"),
  player_advantage_elo: BigDecimal("35.0"),
  season_elo_carryover_factor: BigDecimal("0.5"),
  goal_points: BigDecimal("1.0"),
  assist_points: BigDecimal("0.7"),
  mvp_max_points: BigDecimal("4.0"),
  def_max_points: BigDecimal("3.0"),
  voting_bonus_cap: BigDecimal("5.0"),
  expected_voters_count: 8,
  mvp_vote_bonus: 10,
  def_vote_bonus: 10
)

players = DEMO_PLAYERS.each_with_object({}) do |attributes, lookup|
  player = Player.create!(
    **attributes,
    description: "#{attributes.fetch(:name)} is part of the seeded demo league.",
    approval_status: "approved",
    approved_at: Time.current,
    active: true
  )
  lookup[player.nickname] = player
end

match_day_payloads = [
  {
    played_on: "2026-06-05",
    original_teams: [
      { name: "Red Demo", players: [ "seed-adam", "seed-jan", "seed-marek", "seed-piotr" ] },
      { name: "Blue Demo", players: [ "seed-kamil", "seed-tomek", "seed-bartek", "seed-lukasz" ] }
    ],
    matches: [
      {
        started_at: "2026-06-05 19:00",
        finished_at: "2026-06-05 19:35",
        teams: [
          { name: "Red Demo", players: [ "seed-adam", "seed-jan", "seed-marek", "seed-piotr" ] },
          { name: "Blue Demo", players: [ "seed-kamil", "seed-tomek", "seed-bartek", "seed-lukasz" ] }
        ],
        goals: [
          { team: "Red Demo", scorer: "seed-adam", assistant: "seed-jan" },
          { team: "Blue Demo", scorer: "seed-kamil", assistant: "seed-tomek" },
          { team: "Red Demo", scorer: "seed-adam", assistant: "seed-marek" }
        ]
      },
      {
        started_at: "2026-06-05 19:45",
        finished_at: "2026-06-05 20:15",
        teams: [
          { name: "Red Demo", players: [ "seed-adam", "seed-tomek", "seed-marek", "seed-lukasz" ] },
          { name: "Blue Demo", players: [ "seed-kamil", "seed-jan", "seed-bartek", "seed-piotr" ] }
        ],
        goals: [
          { team: "Blue Demo", scorer: "seed-kamil", assistant: "seed-jan" },
          { team: "Red Demo", scorer: "seed-tomek", assistant: "seed-adam" }
        ]
      }
    ]
  },
  {
    played_on: "2026-06-12",
    original_teams: [
      { name: "Green Demo", players: [ "seed-adam", "seed-kamil", "seed-bartek", "seed-piotr" ] },
      { name: "White Demo", players: [ "seed-jan", "seed-tomek", "seed-marek", "seed-lukasz" ] }
    ],
    matches: [
      {
        started_at: "2026-06-12 19:00",
        finished_at: "2026-06-12 19:40",
        teams: [
          { name: "Green Demo", players: [ "seed-adam", "seed-kamil", "seed-bartek", "seed-piotr" ] },
          { name: "White Demo", players: [ "seed-jan", "seed-tomek", "seed-marek", "seed-lukasz" ] }
        ],
        goals: [
          { team: "White Demo", scorer: "seed-jan", assistant: "seed-tomek" },
          { team: "Green Demo", scorer: "seed-kamil", assistant: "seed-adam" },
          { team: "White Demo", scorer: "seed-tomek", assistant: "seed-jan" }
        ]
      },
      {
        started_at: "2026-06-12 19:50",
        finished_at: "2026-06-12 20:20",
        teams: [
          { name: "Green Demo", players: [ "seed-adam", "seed-jan", "seed-bartek", "seed-lukasz" ] },
          { name: "White Demo", players: [ "seed-kamil", "seed-tomek", "seed-marek", "seed-piotr" ] }
        ],
        goals: [
          { team: "Green Demo", scorer: "seed-jan", assistant: "seed-adam" },
          { team: "Green Demo", scorer: "seed-adam" },
          { team: "White Demo", scorer: "seed-kamil", assistant: "seed-marek" }
        ]
      }
    ]
  },
  {
    played_on: "2026-06-19",
    original_teams: [
      { name: "Orange Demo", players: [ "seed-adam", "seed-tomek", "seed-marek", "seed-piotr" ] },
      { name: "Black Demo", players: [ "seed-kamil", "seed-jan", "seed-bartek", "seed-lukasz" ] }
    ],
    matches: [
      {
        started_at: "2026-06-19 19:00",
        finished_at: "2026-06-19 19:35",
        teams: [
          { name: "Orange Demo", players: [ "seed-adam", "seed-tomek", "seed-marek", "seed-piotr" ] },
          { name: "Black Demo", players: [ "seed-kamil", "seed-jan", "seed-bartek", "seed-lukasz" ] }
        ],
        goals: [
          { team: "Orange Demo", scorer: "seed-tomek", assistant: "seed-adam" },
          { team: "Black Demo", scorer: "seed-jan", assistant: "seed-kamil" }
        ]
      },
      {
        started_at: "2026-06-19 19:45",
        finished_at: "2026-06-19 20:25",
        teams: [
          { name: "Orange Demo", players: [ "seed-adam", "seed-kamil", "seed-marek", "seed-lukasz" ] },
          { name: "Black Demo", players: [ "seed-tomek", "seed-jan", "seed-bartek", "seed-piotr" ] }
        ],
        goals: [
          { team: "Orange Demo", scorer: "seed-adam", assistant: "seed-kamil" },
          { team: "Orange Demo", scorer: "seed-kamil", assistant: "seed-adam" },
          { team: "Black Demo", scorer: "seed-jan", assistant: "seed-tomek" },
          { team: "Orange Demo", scorer: "seed-adam", assistant: "seed-marek" }
        ]
      }
    ]
  }
]

match_days = match_day_payloads.map do |payload|
  import_demo_match_day!(season:, payload:)
end

match_days.each do |match_day|
  submit_demo_votes!(match_day:, players:)
end

puts "Seeded #{DEMO_SEASON_NAME}"
puts "Players: #{Player.where(phone: DEMO_PLAYERS.map { |player| player.fetch(:phone) }).count}"
puts "Match days: #{season.match_days.count}"
puts "Matches: #{season.match_days.joins(:matches).count}"
