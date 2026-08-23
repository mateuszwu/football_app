require "rails_helper"

RSpec.describe "Application stylesheet" do
  describe "dashboard ranking accents" do
    it "uses the neutral text color for ranking positions and the duo separator" do
      stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read
      ranking_rule = stylesheet[/\.ranking-preview__rank\s*\{(?<body>.*?)\}/m, :body]
      duo_separator_rule = stylesheet[/\.dashboard-best-duo__plus\s*\{(?<body>.*?)\}/m, :body]

      expect(ranking_rule).to include("color: #94a3b8;")
      expect(stylesheet).not_to include(".ranking-preview__row:first-child .ranking-preview__rank")
      expect(duo_separator_rule).to include("color: var(--text-muted);")
    end
  end
end
