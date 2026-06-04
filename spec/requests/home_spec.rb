require "rails_helper"

RSpec.describe "Home page" do
  describe "GET /" do
    context "when public visitor opens the app" do
      it "renders the public dashboard and navigation" do
        path = root_path

        get path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Football App")
        expect(response.body).to include("Dashboard")
        expect(response.body).to include("Leaderboardy")
        expect(response.body).to include("Zawodnicy")
        expect(response.body).to include("Zaloguj")
      end
    end

    context "when public visitor opens the app without player data" do
      it "does not render private phone data" do
        path = root_path

        get path

        expect(response.body).not_to include("phone")
        expect(response.body).not_to include("telefon")
      end
    end
  end
end
