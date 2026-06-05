FactoryBot.define do
  factory :season do
    sequence(:name) { |number| "Season #{number}" }
    starts_on { Date.new(2026, 1, 1) }
    ends_on { Date.new(2026, 12, 31) }
    active { false }
    initial_elo { 1000 }
    elo_k_factor { 32 }
    mvp_vote_bonus { 10 }
    def_vote_bonus { 10 }
  end
end
