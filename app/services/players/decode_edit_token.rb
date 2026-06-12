module Players
  class DecodeEditToken
    ALGORITHM = GenerateEditToken::ALGORITHM

    def self.call(token:)
      new(token:).call
    end

    def initialize(token:)
      @token = token
    end

    def call
      payload, = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: ALGORITHM)
      return nil unless payload["purpose"] == GenerateEditToken::PURPOSE

      payload
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end

    private

    attr_reader :token
  end
end
