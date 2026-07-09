require "rails_helper"

RSpec.describe MatchesHelper do
  describe "#match_report_duration" do
    it "formats minute durations" do
      result = helper.match_report_duration(2_110)

      expect(result).to eq("35:10")
    end

    it "formats hour durations" do
      result = helper.match_report_duration(3_661)

      expect(result).to eq("01:01:01")
    end
  end

  describe "#match_report_minute" do
    it "returns a dash when time is missing" do
      result = helper.match_report_minute(nil)

      expect(result).to eq("—")
    end

    it "returns the one-based match minute" do
      result = helper.match_report_minute(720)

      expect(result).to eq("13'")
    end
  end

  describe "#match_report_score" do
    it "formats team scores" do
      result = helper.match_report_score({ team_a: 2, team_b: 1 })

      expect(result).to eq("2 : 1")
    end
  end

  describe "#match_report_compact_score" do
    it "formats compact team scores" do
      result = helper.match_report_compact_score({ team_a: 2, team_b: 1 })

      expect(result).to eq("2:1")
    end
  end

  describe "#match_player_profile_link" do
    it "links approved active players" do
      player = create(:player, name: "Adam Demo", approval_status: "approved", active: true)

      result = helper.match_player_profile_link(player, class_name: "match-player-link")

      expect(result).to include("href=\"/players/#{player.id}\"")
      expect(result).to include("class=\"match-player-link\"")
      expect(result).to include("Adam Demo")
    end

    it "renders plain names for non-public players" do
      player = create(:player, name: "Adam Demo", approval_status: "pending", active: true)

      result = helper.match_player_profile_link(player, class_name: "match-player-link")

      expect(result).to eq("Adam Demo")
    end
  end

  describe "#match_report_votes_count" do
    it "formats singular, few and many vote counts" do
      expect(helper.match_report_votes_count(1)).to eq("1 głos")
      expect(helper.match_report_votes_count(3)).to eq("3 głosy")
      expect(helper.match_report_votes_count(12)).to eq("12 głosów")
    end
  end

  describe "#match_player_initials" do
    it "returns initials from the public player name" do
      player = build(:player, name: "Adam Demo")

      result = helper.match_player_initials(player)

      expect(result).to eq("AD")
    end
  end

  describe "#match_player_identity_avatar" do
    it "renders the persisted profile icon and color" do
      player = build(:player, name: "Adam Demo", profile_icon: "chess-queen", profile_color_hex: "#C084FC")

      result = helper.match_player_identity_avatar(player)

      expect(result).to include("player-identity-badge")
      expect(result).to include("--player-color: #C084FC")
      expect(result).to include("lucide-chess-queen")
      expect(result).not_to include(">AD<")
    end

    it "falls back to default identity when identity is missing" do
      player = build(:player, name: "Adam Demo", profile_icon: nil, profile_color_hex: nil, profile_color_key: nil)

      result = helper.match_player_identity_avatar(player)

      expect(result).to include("--player-color: #374151")
      expect(result).to include("lucide-user-round")
    end
  end

  describe "#match_team_captain" do
    it "returns the persisted team captain" do
      team = create(:team)
      later_player = create(:player, name: "Later Demo")
      captain = create(:player, name: "Captain Demo")
      create(:team_player, team:, player: later_player, position: 2)
      create(:team_player, team:, player: captain, position: 1)
      team.update!(captain:)

      result = helper.match_team_captain(team)

      expect(result).to eq(captain)
    end
  end

  describe "#match_team_captain_mark" do
    it "renders the captain chip from persisted color and icon" do
      team = create(:team)
      captain = create(:player, name: "Captain Demo")
      captain.update_columns(profile_color_key: "red_dark", profile_color_hex: "#B91C1C", profile_icon: "sun")
      create(:team_player, team:, player: captain, position: 1)
      team.update!(captain:)

      result = helper.match_team_captain_mark(team)

      expect(result).to include("match-team-captain")
      expect(result).to include("title=\"Captain Demo\"")
      expect(result).to include("--captain-color: #B91C1C")
      expect(result).to include("lucide-sun")
      expect(result).to include("Kapitan")
      expect(result).to include("Captain Demo")
    end
  end
end
