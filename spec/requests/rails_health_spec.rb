require "rails_helper"

RSpec.describe "Rails health check" do
  describe "GET /up" do
    context "when the application boots" do
      it "returns a successful response" do
        # arrange
        path = rails_health_check_path

        # act
        get path

        # assert
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
