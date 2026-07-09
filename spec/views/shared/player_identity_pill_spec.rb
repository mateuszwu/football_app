require "rails_helper"

RSpec.describe "shared/_player_identity_pill" do
  it "renders the default size, variant, and player name" do
    player = create(:player, name: "Adam Demo")

    render partial: "shared/player_identity_pill", locals: { player: }

    expect(rendered).to include(
      "player-identity-pill player-identity-pill--sm player-identity-pill--default"
    )
    expect(rendered).to include("player-identity-pill__name")
    expect(rendered).to include("Adam Demo")
  end

  it "supports compact icon-only rendering with a custom maximum width" do
    player = create(
      :player,
      name: "Marek Demo",
      profile_color_key: "gold",
      profile_color_hex: "#FACC15",
      profile_icon: "flame"
    )

    render partial: "shared/player_identity_pill",
      locals: {
        player:,
        size: :xs,
        variant: :compact,
        max_width: "120px",
        show_name: false
      }

    expect(rendered).to include(
      "player-identity-pill player-identity-pill--xs player-identity-pill--compact"
    )
    expect(rendered).to include("--player-color: #FACC15; max-width: 120px")
    expect(rendered).to include("lucide-flame")
    expect(rendered).not_to include("player-identity-pill__name")
    expect(rendered).not_to include(">Marek Demo</span>")
  end
end
