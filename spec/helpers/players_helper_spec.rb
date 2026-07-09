require "rails_helper"

RSpec.describe PlayersHelper do
  describe "#player_profile_tabs" do
    it "returns the configured profile tabs" do
      expect(helper.player_profile_tabs).to include("overview" => "layout-dashboard", "synergy" => "network")
    end
  end

  describe "#player_directory_initials" do
    it "returns up to two initials from the player name" do
      player = build(:player, name: "Adam Demo")

      expect(helper.player_directory_initials(player)).to eq("AD")
    end
  end

  describe "#player_directory_elo" do
    it "prefers the season stat elo over the player elo" do
      season_stat = Struct.new(:elo).new(1104)
      card = Struct.new(:season_stat, :player).new(season_stat, build(:player, elo: 1001))

      expect(helper.player_directory_elo(card)).to eq(1104)
    end

    it "falls back to the player elo or dash" do
      card_with_elo = Struct.new(:season_stat, :player).new(nil, build(:player, elo: 1001))
      card_without_elo = Struct.new(:season_stat, :player).new(nil, build(:player, elo: nil))

      expect(helper.player_directory_elo(card_with_elo)).to eq(1001)
      expect(helper.player_directory_elo(card_without_elo)).to eq("—")
    end
  end

  describe "#player_directory_last_played" do
    it "formats a last played date" do
      card = Struct.new(:last_played_on).new(Date.new(2026, 6, 19))

      expect(helper.player_directory_last_played(card)).to eq("2026-06-19")
    end

    it "returns a compact empty label when the player has not played" do
      card = Struct.new(:last_played_on).new(nil)

      expect(helper.player_directory_last_played(card)).to eq("Brak meczów")
    end
  end

  describe "#player_directory_record" do
    it "joins wins, draws and losses" do
      card = Struct.new(:wins, :draws, :losses).new(3, 1, 2)

      expect(helper.player_directory_record(card)).to eq("3-1-2")
    end
  end

  describe "#player_profile_tab_path" do
    it "builds a profile tab path with the selected season" do
      player = create(:player)
      season = create(:season)
      profile = Struct.new(:season).new(season)

      expect(helper.player_profile_tab_path(player, profile, "stats")).to eq("/players/#{player.id}?season_id=#{season.id}&tab=stats")
    end
  end

  describe "#player_profile_result_label" do
    it "returns Polish result initials" do
      expect(helper.player_profile_result_label(Team::RESULT_WIN)).to eq("W")
      expect(helper.player_profile_result_label(Team::RESULT_DRAW)).to eq("R")
      expect(helper.player_profile_result_label(Team::RESULT_LOSS)).to eq("P")
      expect(helper.player_profile_result_label("unknown")).to eq("—")
    end
  end

  describe "#player_profile_signed_delta" do
    it "formats positive, negative and blank deltas" do
      expect(helper.player_profile_signed_delta(8)).to eq("+8")
      expect(helper.player_profile_signed_delta(-4)).to eq("-4")
      expect(helper.player_profile_signed_delta(nil)).to eq("—")
    end
  end

  describe "#player_profile_rate" do
    it "formats decimal values without insignificant zeros" do
      expect(helper.player_profile_rate(12.50)).to eq("12.5")
    end
  end

  describe "#player_profile_partner" do
    it "returns the other player from a relationship result" do
      player = create(:player)
      partner = create(:player, name: "Partner Demo", nickname: "partner-demo", phone: "+48999999998")
      result = Struct.new(:players).new([ player, partner ])

      expect(helper.player_profile_partner(result, player)).to eq(partner)
    end
  end

  describe "#player_profile_duo_names" do
    it "renders linked player names separated by a plus sign" do
      first_player = create(:player, name: "Adam Demo")
      second_player = create(:player, name: "Marek Demo", nickname: "marek-demo", phone: "+48999999998")
      result = Struct.new(:players).new([ first_player, second_player ])

      html = helper.player_profile_duo_names(result)

      expect(html).to include("/players/#{first_player.id}")
      expect(html).to include("/players/#{second_player.id}")
      expect(html).to include("Adam Demo")
      expect(html).to include("Marek Demo")
      expect(html).to include("relationship-duo-card__plus")
    end
  end

  describe "#player_profile_chart_data" do
    it "serializes data for chart attributes" do
      expect(helper.player_profile_chart_data({ labels: [ "A" ], values: [ 1 ] })).to include("\"labels\"")
    end
  end
end
