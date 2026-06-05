require "rails_helper"

RSpec.describe Season do
  describe "validations" do
    context "when required attributes are present" do
      it "creates a season" do
        season = build(:season)

        expect(season).to be_valid
      end
    end

    context "when name is missing" do
      it "is invalid" do
        season = build(:season, name: nil)

        expect(season).not_to be_valid
        expect(season.errors[:name]).to include("can't be blank")
      end
    end

    context "when name is already taken" do
      it "is invalid" do
        create(:season, name: "Spring 2026")
        season = build(:season, name: "Spring 2026")

        expect(season).not_to be_valid
        expect(season.errors[:name]).to include("has already been taken")
      end
    end

    context "when starts_on is missing" do
      it "is invalid" do
        season = build(:season, starts_on: nil)

        expect(season).not_to be_valid
        expect(season.errors[:starts_on]).to include("can't be blank")
      end
    end

    context "when ends_on is before starts_on" do
      it "is invalid" do
        season = build(:season, starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 5, 31))

        expect(season).not_to be_valid
        expect(season.errors[:ends_on]).to include("must be on or after starts on")
      end
    end

    context "when Elo settings are positive integers" do
      it "is valid" do
        season = build(:season, initial_elo: 1200, elo_k_factor: 24)

        expect(season).to be_valid
      end
    end

    context "when Elo settings are not positive" do
      it "is invalid" do
        season = build(:season, initial_elo: 0, elo_k_factor: -1)

        expect(season).not_to be_valid
        expect(season.errors[:initial_elo]).to include("must be greater than 0")
        expect(season.errors[:elo_k_factor]).to include("must be greater than 0")
      end
    end

    context "when performance bonuses are non-negative integers" do
      it "is valid" do
        season = build(:season, mvp_vote_bonus: 0, def_vote_bonus: 5)

        expect(season).to be_valid
      end
    end

    context "when performance bonuses are negative" do
      it "is invalid" do
        season = build(:season, mvp_vote_bonus: -1, def_vote_bonus: -1)

        expect(season).not_to be_valid
        expect(season.errors[:mvp_vote_bonus]).to include("must be greater than or equal to 0")
        expect(season.errors[:def_vote_bonus]).to include("must be greater than or equal to 0")
      end
    end
  end

  describe ".active" do
    context "when seasons have mixed active states" do
      it "returns active seasons only" do
        active_season = create(:season, active: true)
        create(:season, active: false)

        result = described_class.active

        expect(result).to contain_exactly(active_season)
      end
    end
  end

  describe ".current_active" do
    context "when there is one active season" do
      it "returns the active season" do
        active_season = create(:season, active: true)
        create(:season, active: false)

        result = described_class.current_active

        expect(result).to eq(active_season)
      end
    end

    context "when there are multiple active seasons" do
      it "returns the latest one by start date" do
        create(:season, name: "Spring 2026", active: true, starts_on: Date.new(2026, 3, 1))
        latest_season = create(:season, name: "Summer 2026", active: true, starts_on: Date.new(2026, 6, 1))

        result = described_class.current_active

        expect(result).to eq(latest_season)
      end
    end

    context "when there is no active season" do
      it "returns nil" do
        create(:season, active: false)

        result = described_class.current_active

        expect(result).to be_nil
      end
    end
  end

  describe "#match_days_count" do
    context "when the season has match days" do
      it "returns the number of match days in the season" do
        season = create(:season)
        create(:match_day, season: season, played_on: Date.new(2026, 6, 5))
        create(:match_day, season: season, played_on: Date.new(2026, 6, 12))
        create(:match_day, season: create(:season))

        result = season.match_days_count

        expect(result).to eq(2)
      end
    end
  end

  describe "#player_appearances_count" do
    context "when players appear across match days" do
      it "returns the number of player appearances in the season" do
        season = create(:season)
        player = create(:player)
        first_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 12))
        create(:match_day_player, match_day: first_match_day, player: player)
        create(:match_day_player, match_day: second_match_day, player: player)
        create(:match_day_player, match_day: create(:match_day, season: create(:season)), player: create(:player))

        result = season.player_appearances_count

        expect(result).to eq(2)
      end
    end
  end

  describe "#unique_players_count" do
    context "when a player appears more than once" do
      it "counts each player once within the season" do
        season = create(:season)
        player = create(:player)
        other_player = create(:player)
        first_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 12))
        create(:match_day_player, match_day: first_match_day, player: player)
        create(:match_day_player, match_day: second_match_day, player: player)
        create(:match_day_player, match_day: second_match_day, player: other_player)

        result = season.unique_players_count

        expect(result).to eq(2)
      end
    end
  end

  describe "#recent_match_days" do
    context "when the season has multiple match days" do
      it "returns match days ordered from newest to oldest" do
        season = create(:season)
        older_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5))
        latest_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 12))
        create(:match_day, season: create(:season), played_on: Date.new(2026, 6, 19))

        result = season.recent_match_days

        expect(result).to eq([ latest_match_day, older_match_day ])
      end
    end
  end
end
