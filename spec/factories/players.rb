FactoryBot.define do
  factory :player do
    sequence(:name) { |number| "Player #{number}" }
    sequence(:nickname) { |number| "player#{number}" }
    sequence(:phone) { |number| "+48123000#{number.to_s.rjust(3, "0")}" }
    description { "Regular football player" }
    active { true }
  end
end
