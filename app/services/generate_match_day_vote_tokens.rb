class GenerateMatchDayVoteTokens
  def self.call(match_day:, expires_at: 48.hours.from_now)
    Voting::GenerateMatchDayVoteTokens.call(match_day:, expires_at:)
  end
end
