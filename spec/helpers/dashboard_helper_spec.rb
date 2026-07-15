require "rails_helper"

RSpec.describe DashboardHelper do
  describe "#dashboard_icon" do
    it "renders a decorative Lucide icon" do
      html = helper.dashboard_icon("trophy")

      expect(html).to include('class="tile-icon"')
      expect(html).to include('aria-hidden="true"')
      expect(html).to include("<svg")
      expect(html).to include("viewBox=\"0 0 24 24\"")
      expect(html).to include("<path")
    end

    it "supports custom wrapper classes for watermarks" do
      html = helper.dashboard_icon("network", class_name: "dashboard-tile__watermark")

      expect(html).to include('class="decorative-card-icon dashboard-tile__watermark"')
      expect(html).to include("<svg")
    end
  end

  describe "#safe_lucide_icon" do
    it "renders the fallback icon when the requested icon is unavailable" do
      html = helper.safe_lucide_icon("missing-icon", fallback: "circle-dot", class_name: "ui-icon ui-icon--sm")

      expect(html).to include('class="ui-icon ui-icon--sm"')
      expect(html).to include("<svg")
      expect(html).to include('class="lucide lucide-circle-dot"')
    end

    it "falls back to a circle when both icon names are unavailable" do
      html = helper.safe_lucide_icon("missing-icon", fallback: "also-missing")

      expect(html).to include('class="lucide lucide-circle"')
    end

    it "reraises non-icon errors from the requested icon" do
      allow(helper).to receive(:render_lucide_icon).with("broken-icon").and_raise(ArgumentError, "Invalid options")

      expect { helper.safe_lucide_icon("broken-icon") }.to raise_error(ArgumentError, "Invalid options")
    end

    it "reraises non-icon errors from the fallback icon" do
      allow(helper).to receive(:render_lucide_icon).with("missing-icon").and_raise(ArgumentError, "Unknown icon missing-icon")
      allow(helper).to receive(:render_lucide_icon).with("broken-fallback").and_raise(ArgumentError, "Invalid options")

      expect { helper.safe_lucide_icon("missing-icon", fallback: "broken-fallback") }
        .to raise_error(ArgumentError, "Invalid options")
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

  describe "#dashboard_count" do
    it "translates dashboard count labels" do
      expect(helper.dashboard_count("goals_count", 2)).to eq("2 gole")
    end
  end
end
