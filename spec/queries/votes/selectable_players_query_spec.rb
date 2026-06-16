require "rails_helper"

RSpec.describe Votes::SelectablePlayersQuery do
  describe ".call" do
    context "when the match day has a voter and other players" do
      it "returns non-voter players ordered by name" do
        voter = create(:player, name: "Voter")
        second_player = create(:player, name: "Zed")
        first_player = create(:player, name: "Adam")
        match_day = create(:match_day)
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        create(:match_day_player, match_day: match_day, player: second_player)
        create(:match_day_player, match_day: match_day, player: first_player)
        match_day_vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player)

        result = described_class.call(match_day_vote_token: match_day_vote_token)

        expect(result).to eq([ first_player, second_player ])
      end
    end

    context "when the voter is the only player on the match day" do
      it "returns an empty relation" do
        voter = create(:player, name: "Voter")
        match_day = create(:match_day)
        voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
        match_day_vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player)

        result = described_class.call(match_day_vote_token: match_day_vote_token)

        expect(result).to be_empty
      end
    end
  end
end
