module Players
  class GenerateEditToken
    ALGORITHM = "HS256".freeze
    EXPIRATION = 6.hours.freeze
    PURPOSE = "player_edit".freeze

    def self.call(player:)
      new(player:).call
    end

    def initialize(player:)
      @player = player
    end

    def call
      JWT.encode(payload, Rails.application.secret_key_base, ALGORITHM)
    end

    private

    attr_reader :player

    def payload
      {
        "player_id" => player.id,
        "purpose" => PURPOSE,
        "exp" => EXPIRATION.from_now.to_i
      }
    end
  end
end
