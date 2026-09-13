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

  describe "guest mobile player directory" do
    it "keeps filter controls at the iOS zoom-safe font size" do
      stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read
      mobile_rules = stylesheet[/@media \(max-width: 767px\)(?<body>.*)\z/m, :body]

      expect(mobile_rules).to include(".players-directory-field input")
      expect(mobile_rules).to match(/\.players-directory-field input,\s*\.players-directory-field select\s*\{[^}]*font-size: 16px;/m)
    end

    it "keeps roster metrics in a compact three-column layout" do
      stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read
      mobile_rules = stylesheet[/@media \(max-width: 767px\)(?<body>.*)\z/m, :body]

      expect(mobile_rules).to match(/\.roster-card__main\s*\{[^}]*grid-template-columns: repeat\(3, minmax\(0, 1fr\)\);/m)
    end
  end
end
