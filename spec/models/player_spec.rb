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
      it "is invalid" do
        player = build(:player, phone: nil)

        expect(player).not_to be_valid
        expect(player.errors[:phone]).to include("can't be blank")
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
end
