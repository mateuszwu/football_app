module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_token

    private

    def authenticate_api_token
      return if valid_api_token?(bearer_token)

      head :unauthorized
    end

    def valid_api_token?(token)
      expected_token = api_token

      return false if token.blank? || expected_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
    end

    def bearer_token
      authorization = request.authorization.to_s

      authorization.delete_prefix("Bearer ").presence
    end

    def api_token
      ENV["FOOTBALL_APP_API_TOKEN"].presence ||
        credentials_value(:api, :token) ||
        credentials_value(:api_token)
    end

    def credentials_value(*keys)
      Rails.application.credentials.dig(*keys).presence
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::EncryptedFile::MissingKeyError
      nil
    end
  end
end
