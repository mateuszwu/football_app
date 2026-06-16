require "rails_helper"

RSpec.describe Voting::PrepareMatchDayVoteInvites do
  describe ".call" do
    it "generates missing tokens and returns per-player invite payloads" do
      match_day = create(:match_day)
      adam = create(:player, name: "Adam", nickname: "adam", phone: "+48222222222", active: true)
      zed = create(:player, name: "Zed", nickname: "zed", phone: "+48111111111", active: true)
      adam_match_day_player = create(:match_day_player, match_day:, player: adam)
      zed_match_day_player = create(:match_day_player, match_day:, player: zed)

      result = described_class.call(match_day:, base_url: "http://www.example.com")

      expect(adam_match_day_player.reload.match_day_vote_token).to be_present
      expect(zed_match_day_player.reload.match_day_vote_token).to be_present
      expect(result).to eq(
        [
          {
            name: "Adam",
            phone: "+48222222222",
            sms_body: "Czesc Adam, zaglosuj na MVP i DEF: http://www.example.com/votes/#{adam_match_day_player.match_day_vote_token.token}"
          },
          {
            name: "Zed",
            phone: "+48111111111",
            sms_body: "Czesc Zed, zaglosuj na MVP i DEF: http://www.example.com/votes/#{zed_match_day_player.match_day_vote_token.token}"
          }
        ]
      )
    end

    it "keeps existing tokens" do
      match_day = create(:match_day)
      player = create(:player, name: "Adam", nickname: "adam", phone: "+48222222222", active: true)
      match_day_player = create(:match_day_player, match_day:, player:)
      existing_token = create(:match_day_vote_token, match_day_player:, token: "existing-token")

      result = described_class.call(match_day:, base_url: "http://www.example.com")

      expect(match_day_player.reload.match_day_vote_token).to eq(existing_token)
      expect(result.first[:sms_body]).to include("/votes/existing-token")
    end
  end
end
