require "rails_helper"

RSpec.describe Players::AssignIdentity do
  describe ".call" do
    context "when unused icons are available" do
      it "assigns an unused icon" do
        used_icon = PlayerIdentity.icons.first
        unused_icon = PlayerIdentity.icons.second
        used_color = PlayerIdentity.colors.first
        player = create(:player, profile_icon: nil, profile_color_key: nil, profile_color_hex: nil)
        create(
          :player,
          approval_status: "approved",
          active: true,
          profile_icon: used_icon,
          profile_color_key: used_color.fetch(:key),
          profile_color_hex: used_color.fetch(:hex)
        )
        player.update_columns(profile_icon: nil, profile_color_key: nil, profile_color_hex: nil)

        described_class.call(player:)

        expect(player.reload.profile_icon).to eq(unused_icon)
      end
    end

    context "when assigning an icon" do
      it "never assigns a reserved application icon" do
        player = create(:player)
        player.update_columns(profile_icon: nil, profile_color_key: nil, profile_color_hex: nil)

        described_class.call(player:)

        expect(PlayerIdentity.reserved_app_icons).not_to include(player.reload.profile_icon)
      end
    end

    context "when not all icons are used" do
      it "does not duplicate an icon" do
        player = create(:player, profile_icon: nil, profile_color_key: nil, profile_color_hex: nil)
        PlayerIdentity.icons.first(3).each_with_index do |icon, index|
          color = PlayerIdentity.colors[index]
          create(
            :player,
            approval_status: "approved",
            active: true,
            profile_icon: icon,
            profile_color_key: color.fetch(:key),
            profile_color_hex: color.fetch(:hex)
          )
        end
        player.update_columns(profile_icon: nil, profile_color_key: nil, profile_color_hex: nil)

        described_class.call(player:)

        expect(PlayerIdentity.icons.first(3)).not_to include(player.reload.profile_icon)
      end
    end

    context "when all icons are already used" do
      it "reuses the least-used icon" do
        first_icon = PlayerIdentity.icons.first
        expected_icon = PlayerIdentity.icons.second
        PlayerIdentity.icons.each_with_index do |icon, index|
          color = PlayerIdentity.colors[index % PlayerIdentity.colors.length]
          create(
            :player,
            approval_status: "approved",
            active: true,
            profile_icon: icon,
            profile_color_key: color.fetch(:key),
            profile_color_hex: color.fetch(:hex)
          )
        end
        create(
          :player,
          approval_status: "approved",
          active: true,
          profile_icon: first_icon,
          profile_color_key: PlayerIdentity.colors.last.fetch(:key),
          profile_color_hex: PlayerIdentity.colors.last.fetch(:hex)
        )
        player = create(:player)
        player.update_columns(profile_icon: nil, profile_color_key: nil, profile_color_hex: nil)

        described_class.call(player:)

        expect(player.reload.profile_icon).to eq(expected_icon)
      end
    end

    context "when the preferred pair already exists" do
      it "avoids a duplicate color and icon pair when possible" do
        icon = PlayerIdentity.icons.first
        first_color = PlayerIdentity.colors.first
        second_color = PlayerIdentity.colors.second
        create(
          :player,
          approval_status: "approved",
          active: true,
          profile_icon: icon,
          profile_color_key: first_color.fetch(:key),
          profile_color_hex: first_color.fetch(:hex)
        )
        player = create(
          :player,
          profile_icon: icon,
          profile_color_key: nil,
          profile_color_hex: nil
        )
        player.update_columns(profile_icon: icon, profile_color_key: nil, profile_color_hex: nil)

        described_class.call(player:)

        player.reload
        expect(player.profile_icon).to eq(icon)
        expect(player.profile_color_key).to eq(second_color.fetch(:key))
        expect(player.profile_color_hex).to eq(second_color.fetch(:hex))
      end
    end

    context "when the player already has a manually selected icon" do
      it "does not overwrite the icon" do
        manual_icon = PlayerIdentity.icons.last
        player = create(:player, profile_icon: manual_icon)
        player.update_columns(profile_icon: manual_icon, profile_color_key: nil, profile_color_hex: nil)

        described_class.call(player:)

        expect(player.reload.profile_icon).to eq(manual_icon)
      end
    end

    context "when the player already has a manually selected color" do
      it "does not overwrite the color" do
        manual_color = PlayerIdentity.colors.last
        player = create(
          :player,
          profile_icon: nil,
          profile_color_key: manual_color.fetch(:key),
          profile_color_hex: manual_color.fetch(:hex)
        )
        player.update_columns(
          profile_icon: nil,
          profile_color_key: manual_color.fetch(:key),
          profile_color_hex: manual_color.fetch(:hex)
        )

        described_class.call(player:)

        player.reload
        expect(player.profile_color_key).to eq(manual_color.fetch(:key))
        expect(player.profile_color_hex).to eq(manual_color.fetch(:hex))
      end
    end

    context "when the color key is selected but the hex value is missing" do
      it "fills the color hex from the selected color key" do
        color = PlayerIdentity.colors.second
        player = create(:player, profile_color_key: color.fetch(:key), profile_color_hex: nil)
        player.update_columns(profile_color_key: color.fetch(:key), profile_color_hex: nil)

        described_class.call(player:)

        expect(player.reload.profile_color_hex).to eq(color.fetch(:hex))
      end
    end

    context "when identity config is empty" do
      it "assigns fallback identity safely" do
        player = create(:player)
        player.update_columns(profile_icon: nil, profile_color_key: nil, profile_color_hex: nil)
        allow(PlayerIdentity).to receive(:icons).and_return([])
        allow(PlayerIdentity).to receive(:colors).and_return([])

        described_class.call(player:)

        player.reload
        expect(player.profile_icon).to eq("user-round")
        expect(player.profile_color_key).to eq("graphite")
        expect(player.profile_color_hex).to eq("#374151")
      end
    end
  end
end
