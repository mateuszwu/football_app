require "rails_helper"

RSpec.describe Player do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a player" do
        player = build(:player)

        expect(player).to be_valid
      end
    end

    context "when name is missing" do
      it "is invalid" do
        player = build(:player, name: nil)

        expect(player).not_to be_valid
        expect(player.errors[:name]).to include("can't be blank")
      end
    end

    context "when phone is missing" do
      it "is valid" do
        player = build(:player, phone: nil)

        expect(player).to be_valid
      end

      it "allows multiple players without a phone" do
        create(:player, phone: nil)
        player = build(:player, phone: nil)

        expect(player).to be_valid
      end

      it "normalizes a blank phone to nil" do
        player = create(:player, phone: "  ")

        expect(player.reload.phone).to be_nil
      end
    end

    context "when nickname is missing" do
      it "is invalid" do
        player = build(:player, nickname: nil)

        expect(player).not_to be_valid
        expect(player.errors[:nickname]).to include("can't be blank")
      end
    end

    context "when nickname is already taken" do
      it "is invalid" do
        create(:player, nickname: "mati")
        player = build(:player, nickname: "mati")

        expect(player).not_to be_valid
        expect(player.errors[:nickname]).to include("has already been taken")
      end
    end

    context "when phone is already taken" do
      it "is invalid" do
        create(:player, phone: "+48123456789")
        player = build(:player, phone: "+48123456789")

        expect(player).not_to be_valid
        expect(player.errors[:phone]).to include("has already been taken")
      end
    end

    context "when description is missing" do
      it "is invalid" do
        player = build(:player, description: nil)

        expect(player).not_to be_valid
        expect(player.errors[:description]).to include("can't be blank")
      end
    end

    context "when approval status is supported" do
      it "is valid" do
        players = Player::APPROVAL_STATUSES.map { |approval_status| build(:player, approval_status: approval_status) }

        expect(players).to all(be_valid)
      end
    end

    context "when approval status is unsupported" do
      it "is invalid" do
        player = build(:player, approval_status: "archived")

        expect(player).not_to be_valid
        expect(player.errors[:approval_status]).to include("is not included in the list")
      end
    end

    context "when role code is supported" do
      it "is valid" do
        players = Player::ROLE_CODES.map { |role_code| build(:player, role_code: role_code) }

        expect(players).to all(be_valid)
      end
    end

    context "when role code is unsupported" do
      it "is invalid" do
        player = build(:player, role_code: "COACH")

        expect(player).not_to be_valid
        expect(player.errors[:role_code]).to include("is not included in the list")
      end
    end

    context "when profile color data is valid" do
      it "is valid" do
        player = build(:player, profile_color_key: "red_dark", profile_color_hex: "#B91C1C")

        expect(player).to be_valid
      end
    end

    context "when profile color key is unsupported" do
      it "is invalid" do
        player = build(:player, profile_color_key: "neon_green")

        expect(player).not_to be_valid
        expect(player.errors[:profile_color_key]).to include("is not included in the list")
      end
    end

    context "when profile color hex is malformed" do
      it "is invalid" do
        player = build(:player, profile_color_hex: "green")

        expect(player).not_to be_valid
        expect(player.errors[:profile_color_hex]).to include("is invalid")
      end
    end

    context "when profile icon is supported" do
      it "is valid" do
        player = build(:player, profile_icon: "sun")

        expect(player).to be_valid
      end
    end

    context "when profile icon is a fallback-only icon" do
      it "is valid" do
        player = build(:player, profile_icon: "user-round")

        expect(player).to be_valid
      end
    end

    context "when profile icon is reserved for the application" do
      it "is invalid" do
        player = build(:player, profile_icon: "trophy")

        expect(player).not_to be_valid
        expect(player.errors[:profile_icon]).to include("is not included in the list")
      end
    end

    context "when profile icon is unsupported" do
      it "is invalid" do
        player = build(:player, profile_icon: "spaceship")

        expect(player).not_to be_valid
        expect(player.errors[:profile_icon]).to include("is not included in the list")
      end
    end
  end

  describe "#profile_icon_name" do
    context "when the saved icon is reserved for the application" do
      it "returns the fallback icon" do
        player = build(:player, profile_icon: "shield")

        expect(player.profile_icon_name).to eq("user-round")
      end
    end
  end

  describe ".approved" do
    context "when players have mixed approval statuses" do
      it "returns approved players only" do
        approved_player = create(:player, approval_status: "approved")
        create(:player, approval_status: "pending")
        create(:player, approval_status: "rejected")

        result = described_class.approved

        expect(result).to contain_exactly(approved_player)
      end
    end
  end

  describe ".pending" do
    context "when players have mixed approval statuses" do
      it "returns pending players only" do
        pending_player = create(:player, approval_status: "pending")
        create(:player, approval_status: "approved")
        create(:player, approval_status: "rejected")

        result = described_class.pending

        expect(result).to contain_exactly(pending_player)
      end
    end
  end

  describe ".rejected" do
    context "when players have mixed approval statuses" do
      it "returns rejected players only" do
        rejected_player = create(:player, approval_status: "rejected")
        create(:player, approval_status: "approved")
        create(:player, approval_status: "pending")

        result = described_class.rejected

        expect(result).to contain_exactly(rejected_player)
      end
    end
  end

  describe ".active" do
    context "when players have mixed active states" do
      it "returns active players only" do
        active_player = create(:player, active: true)
        create(:player, active: false)

        result = described_class.active

        expect(result).to contain_exactly(active_player)
      end
    end
  end

  describe ".active_public" do
    context "when players have mixed approval and active states" do
      it "returns approved active players only" do
        active_public_player = create(:player, approval_status: "approved", active: true)
        create(:player, approval_status: "pending", active: true)
        create(:player, approval_status: "approved", active: false)

        result = described_class.active_public

        expect(result).to contain_exactly(active_public_player)
      end
    end
  end

  describe "identity assignment" do
    context "when a player is created without profile identity" do
      it "assigns missing identity fields" do
        player = create(:player)

        expect(player.profile_color_key).to be_present
        expect(player.profile_color_hex).to be_present
        expect(player.profile_icon).to be_present
      end
    end
  end

  describe "#profile_color" do
    it "returns a fallback color when profile color is missing" do
      player = build(:player, profile_color_key: nil, profile_color_hex: nil)

      expect(player.profile_color).to eq("#374151")
    end
  end

  describe "#profile_icon_name" do
    it "returns a fallback icon when profile icon is missing" do
      player = build(:player, profile_icon: nil)

      expect(player.profile_icon_name).to eq("user-round")
    end
  end

  describe "#display_name" do
    it "returns the player's persisted name without requiring another field" do
      player = build(:player, name: "Captain Demo")

      expect(player.display_name).to eq("Captain Demo")
    end
  end

  describe "#match_history" do
    context "when the player has played multiple match days" do
      it "returns the player's match days ordered from newest to oldest" do
        player = create(:player)
        current_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        older_match_day = create(:match_day, played_on: Date.new(2026, 5, 29))
        create(:match_day_player, player: player, match_day: older_match_day)
        create(:match_day_player, player: player, match_day: current_match_day)
        create(:match_day_player, player: create(:player), match_day: create(:match_day, played_on: Date.new(2026, 6, 12)))

        result = player.match_history

        expect(result).to eq([ current_match_day, older_match_day ])
      end
    end
  end

  describe "#played_with" do
    it "delegates to the shared match day query" do
      player = create(:player)
      result = instance_double(ActiveRecord::Relation)
      allow(Players::SharedMatchDaysQuery).to receive(:call).with(player: player).and_return(result)

      returned_result = player.played_with

      expect(returned_result).to eq(result)
      expect(Players::SharedMatchDaysQuery).to have_received(:call).with(player: player)
    end
  end

  describe "associations" do
    context "when the record is saved" do
      it "has many team players" do
        player = create(:player)
        team_player = create(:team_player, player: player)

        expect(player.team_players).to contain_exactly(team_player)
      end

      it "has many teams through team players" do
        player = create(:player)
        team = create(:team)
        create(:team_player, player: player, team: team)

        expect(player.teams).to contain_exactly(team)
      end
    end
  end
end
