require "rails_helper"

RSpec.describe Voting::GenerateMatchDayVoteTokens do
  describe ".call" do
    context "when match day players do not have vote tokens" do
      it "creates one vote token per match day player" do
        match_day = create(:match_day)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        first_match_day_player = create(:match_day_player, match_day: match_day, player: first_player)
        second_match_day_player = create(:match_day_player, match_day: match_day, player: second_player)

        result = described_class.call(match_day: match_day)

        expect(result).to be(true)
        expect(first_match_day_player.reload.match_day_vote_token).to be_present
        expect(second_match_day_player.reload.match_day_vote_token).to be_present
        expect(first_match_day_player.match_day_vote_token.token).not_to eq(second_match_day_player.match_day_vote_token.token)
      end
    end

    context "when some match day players already have vote tokens" do
      it "keeps existing tokens and creates only the missing ones" do
        match_day = create(:match_day)
        first_player = create(:player, approval_status: "approved", active: true)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)
        first_match_day_player = create(:match_day_player, match_day: match_day, player: first_player)
        second_match_day_player = create(:match_day_player, match_day: match_day, player: second_player)
        existing_token = first_match_day_player.create_match_day_vote_token!(token: "existing-token")

        result = described_class.call(match_day: match_day)

        expect(result).to be(true)
        expect(first_match_day_player.reload.match_day_vote_token).to eq(existing_token)
        expect(second_match_day_player.reload.match_day_vote_token).to be_present
        expect(second_match_day_player.match_day_vote_token.token).not_to eq("existing-token")
      end
    end

    context "when there are players outside the match day" do
      it "creates tokens only for present players" do
        match_day = create(:match_day)
        present_player = create(:player, approval_status: "approved", active: true)
        absent_player = create(:player, name: "Absent", nickname: "absent", phone: "+48999999997", approval_status: "approved", active: true)
        present_match_day_player = create(:match_day_player, match_day:, player: present_player)
        create(:match_day_player, match_day: create(:match_day), player: absent_player)

        described_class.call(match_day:)

        expect(present_match_day_player.reload.match_day_vote_token).to be_present
        expect(MatchDayVoteToken.joins(:match_day_player).where(match_day_players: { player_id: absent_player.id, match_day_id: match_day.id })).to be_empty
      end
    end
  end
end
