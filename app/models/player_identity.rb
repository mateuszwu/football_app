class PlayerIdentity
  RESERVED_APP_ICONS = %w[
    trophy target shield star medal zap flag circle-dot
  ].freeze

  COLORS = [
    { key: "graphite", name: "Grafitowy", hex: "#374151" },
    { key: "silver", name: "Srebrny", hex: "#CBD5E1" },
    { key: "gold", name: "Złoty", hex: "#FACC15" },
    { key: "black", name: "Czarny", hex: "#020617" },
    { key: "blue_light", name: "Jasny niebieski", hex: "#38BDF8" },
    { key: "blue_dark", name: "Ciemny niebieski", hex: "#1D4ED8" },
    { key: "green_light", name: "Jasny zielony", hex: "#A3E635" },
    { key: "green_dark", name: "Ciemny zielony", hex: "#15803D" },
    { key: "yellow_light", name: "Jasny żółty", hex: "#FEF08A" },
    { key: "yellow_dark", name: "Ciemny żółty", hex: "#CA8A04" },
    { key: "pink_light", name: "Jasny różowy", hex: "#F9A8D4" },
    { key: "pink_dark", name: "Ciemny różowy", hex: "#BE185D" },
    { key: "red_light", name: "Jasny czerwony", hex: "#FCA5A5" },
    { key: "red_dark", name: "Ciemny czerwony", hex: "#B91C1C" },
    { key: "purple_light", name: "Jasny fioletowy", hex: "#C084FC" },
    { key: "purple_dark", name: "Ciemny fioletowy", hex: "#6D28D9" },
    { key: "brown_light", name: "Jasny brązowy", hex: "#D6A676" },
    { key: "brown_dark", name: "Ciemny brązowy", hex: "#7C2D12" }
  ].freeze

  PLAYER_ICONS = %w[
    sun cookie bird bone bug cat dog fish origami paw-print
    rabbit mouse shrimp snail turtle anvil loader-pinwheel brush-cleaning brush eye
    drafting-compass gem puzzle rocket telescope gamepad-2 biceps-flexed chess-knight chess-queen hand-metal
    zodiac-aries music paperclip piggy-bank cake-slice cherry croissant nut wheat dices
    flame ghost gpu hourglass joystick pickaxe sword wand-sparkles rose tree-pine
    plane radiation snowflake key-round bot dumbbell fishing-hook tractor hammer drill
  ].freeze

  DEFAULT_COLOR_KEY = "graphite"
  DEFAULT_ICON = "user-round"
  FALLBACK_ICONS = %w[user-round square-user-round badge].freeze

  def self.colors
    COLORS
  end

  def self.icons
    PLAYER_ICONS
  end

  def self.reserved_app_icons
    RESERVED_APP_ICONS
  end

  def self.color_keys
    COLORS.map { |color| color[:key] }
  end

  def self.color_for(key)
    COLORS.find { |color| color[:key] == key.to_s }
  end

  def self.hex_for(key)
    color_for(key)&.fetch(:hex) || color_for(DEFAULT_COLOR_KEY).fetch(:hex)
  end

  def self.name_for(key)
    color_for(key)&.fetch(:name)
  end

  def self.valid_color_key?(key)
    color_keys.include?(key.to_s)
  end

  def self.valid_icon?(icon)
    PLAYER_ICONS.include?(icon.to_s)
  end

  def self.reserved_icon?(icon)
    RESERVED_APP_ICONS.include?(icon.to_s)
  end

  def self.safe_icon(icon)
    return icon.to_s if valid_icon?(icon)

    DEFAULT_ICON
  end
end
