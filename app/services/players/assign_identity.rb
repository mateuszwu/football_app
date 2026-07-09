require "set"

module Players
  class AssignIdentity
    FALLBACK_COLOR = PlayerIdentity.color_for(PlayerIdentity::DEFAULT_COLOR_KEY).freeze
    FALLBACK_ICON = PlayerIdentity::DEFAULT_ICON

    def self.call(player:)
      new(player:).call
    end

    def initialize(player:)
      @player = player
    end

    def call
      assign_missing_identity
      player.save!
      player
    end

    private

    attr_reader :player

    def assign_missing_identity
      assign_pair if player.profile_color_key.blank? && player.profile_color_hex.blank? && player.profile_icon.blank?
      assign_icon if player.profile_icon.blank?
      assign_color if player.profile_color_key.blank? && player.profile_color_hex.blank?
      fill_color_hex if player.profile_color_key.present? && player.profile_color_hex.blank?
    end

    def assign_pair
      color_key, icon = best_pair
      color = color_for(color_key)

      player.profile_color_key = color.fetch(:key)
      player.profile_color_hex = color.fetch(:hex)
      player.profile_icon = icon
    end

    def assign_icon
      player.profile_icon = best_icon_for(color_key: player.profile_color_key)
    end

    def assign_color
      color = best_color_for(icon: player.profile_icon)

      player.profile_color_key = color.fetch(:key)
      player.profile_color_hex = color.fetch(:hex)
    end

    def fill_color_hex
      player.profile_color_hex = PlayerIdentity.hex_for(player.profile_color_key) || color_for(player.profile_color_key).fetch(:hex)
    end

    def best_pair
      candidate_pairs.min_by do |color_key, icon|
        [
          existing_pairs.include?([ color_key, icon ]) ? 1 : 0,
          pair_counts[[ color_key, icon ]] || 0,
          icon_counts[icon] || 0,
          color_counts[color_key] || 0,
          icon_index(icon),
          color_index(color_key)
        ]
      end
    end

    def best_icon_for(color_key:)
      icons.min_by do |icon|
        [
          color_key.present? && existing_pairs.include?([ color_key, icon ]) ? 1 : 0,
          icon_counts[icon] || 0,
          icon_index(icon)
        ]
      end
    end

    def best_color_for(icon:)
      colors.min_by do |color|
        color_key = color.fetch(:key)

        [
          icon.present? && existing_pairs.include?([ color_key, icon ]) ? 1 : 0,
          pair_counts[[ color_key, icon ]] || 0,
          color_counts[color_key] || 0,
          color_index(color_key)
        ]
      end
    end

    def candidate_pairs
      icons.flat_map do |icon|
        colors.map { |color| [ color.fetch(:key), icon ] }
      end
    end

    def existing_players
      @existing_players ||= Player.active_public.where.not(id: player.id)
    end

    def icon_counts
      @icon_counts ||= existing_players.group(:profile_icon).count
    end

    def color_counts
      @color_counts ||= existing_players.group(:profile_color_key).count
    end

    def pair_counts
      @pair_counts ||= existing_players.pluck(:profile_color_key, :profile_icon).each_with_object(Hash.new(0)) do |pair, counts|
        counts[pair] += 1 if pair.all?(&:present?)
      end
    end

    def existing_pairs
      @existing_pairs ||= pair_counts.keys.to_set
    end

    def colors
      @colors ||= Array(PlayerIdentity.colors).presence || [ FALLBACK_COLOR ]
    end

    def icons
      @icons ||= selectable_icons.presence || [ FALLBACK_ICON ]
    end

    def selectable_icons
      Array(PlayerIdentity.icons).reject { |icon| PlayerIdentity.reserved_icon?(icon) }
    end

    def color_for(color_key)
      colors.find { |color| color.fetch(:key) == color_key } || FALLBACK_COLOR
    end

    def icon_index(icon)
      icons.index(icon) || icons.length
    end

    def color_index(color_key)
      colors.index { |color| color.fetch(:key) == color_key } || colors.length
    end
  end
end
