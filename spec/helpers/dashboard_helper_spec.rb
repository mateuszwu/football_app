require "rails_helper"

RSpec.describe DashboardHelper do
  describe "#dashboard_icon" do
    it "renders a decorative inline SVG icon" do
      html = helper.dashboard_icon("trophy")

      expect(html).to include('class="tile-icon"')
      expect(html).to include('aria-hidden="true"')
      expect(html).to include("<svg")
      expect(html).to include("viewBox=\"0 0 24 24\"")
      expect(html).to include("<path")
    end

    it "supports custom wrapper classes for watermarks" do
      html = helper.dashboard_icon("network", class_name: "dashboard-tile__watermark")

      expect(html).to include('class="dashboard-tile__watermark"')
      expect(html).to include("<svg")
    end
  end

  describe "#dashboard_polish_count" do
    it "formats one, few, and many count labels" do
      one = helper.dashboard_polish_count(1, one: "asysta", few: "asysty", many: "asyst")
      few = helper.dashboard_polish_count(2, one: "asysta", few: "asysty", many: "asyst")
      many = helper.dashboard_polish_count(5, one: "asysta", few: "asysty", many: "asyst")

      expect(one).to eq("1 asysta")
      expect(few).to eq("2 asysty")
      expect(many).to eq("5 asyst")
    end
  end
end
