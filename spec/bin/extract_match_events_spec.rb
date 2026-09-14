require "json"
require "open3"
require "tmpdir"

RSpec.describe "script/extract_match_events.py" do
  let(:script_path) { File.expand_path("../../script/extract_match_events.py", __dir__) }

  describe "extracting event candidates" do
    context "when the transcript contains repeated goal announcements" do
      it "deduplicates goals and retains scorer, assist, score, and match minute" do
        Dir.mktmpdir("extract-match-events-spec-") do |directory|
          input = File.join(directory, "transcript.json")
          output = File.join(directory, "events.json")
          document = {
            "transcription" => [
              segment("00:00:05,000", "00:00:06,000", "Dobra, gotowi? Lecimy!"),
              segment("00:00:10,000", "00:00:11,000", "Damian asysta, Kamil gol"),
              segment("00:00:12,000", "00:00:13,000", "Damian asysta, Kamil gol"),
              segment("00:00:14,000", "00:00:15,000", "Damian asysta, Kamil Barcelona gol"),
              segment("00:00:58,000", "00:00:59,000", "Damian asysta, Kamil gol"),
              segment("00:01:00,000", "00:01:01,000", "Cash asysta, Płaczek gol"),
              segment("00:01:10,000", "00:01:11,000", "Wynik 2:0"),
              segment("00:01:12,000", "00:01:13,000", "To mógł być gol"),
              segment("00:01:20,000", "00:01:21,000", "Koniec meczu")
            ]
          }
          File.write(input, JSON.generate(document))

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--output",
            output,
            "--source-id",
            "match-1"
          )

          expect(status).to be_success, stderr
          result = JSON.parse(File.read(output))
          expect(result.fetch("source_id")).to eq("match-1")
          expect(result.fetch("goals").map { |goal| [ goal["scorer"], goal["assist"] ] }).to eq(
            [ [ "Kamil", "Damian" ], [ "Płaczek", "Cash" ] ]
          )
          first_goal = result.fetch("goals").fetch(0)
          expect(first_goal.fetch("goal_confirmation")).to eq("repeated_within_5_seconds")
          expect(first_goal.fetch("goal_confirmation_count")).to be >= 2
          expect(first_goal.fetch("needs_manual_review")).to be(false)
          expect(result.dig("goals", 0, "match_minute")).to eq(1)
          expect(result.fetch("scores").first).to include("home" => 2, "away" => 0)
          expect(result.fetch("match_ends").length).to eq(1)
        end
      end
    end

    context "when a goal is announced only once" do
      it "keeps it as a manual-review candidate instead of confirming it" do
        Dir.mktmpdir("extract-match-events-spec-") do |directory|
          input = File.join(directory, "transcript.json")
          output = File.join(directory, "events.json")
          document = {
            "transcription" => [
              segment("00:00:05,000", "00:00:06,000", "Start"),
              segment("00:00:10,000", "00:00:11,000", "Kamil gol")
            ]
          }
          File.write(input, JSON.generate(document))

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--output",
            output
          )

          expect(status).to be_success, stderr
          goal = JSON.parse(File.read(output)).fetch("goals").fetch(0)
          expect(goal.fetch("goal_confirmation")).to eq("single_or_spread_announcement")
          expect(goal.fetch("goal_confirmation_count")).to eq(0)
          expect(goal.fetch("needs_manual_review")).to be(true)
        end
      end
    end

    context "when announcements are repeated outside the confirmation window" do
      it "does not confirm them automatically" do
        Dir.mktmpdir("extract-match-events-spec-") do |directory|
          input = File.join(directory, "transcript.json")
          output = File.join(directory, "events.json")
          document = {
            "transcription" => [
              segment("00:00:10,000", "00:00:11,000", "Kamil gol"),
              segment("00:00:20,000", "00:00:21,000", "Kamil gol")
            ]
          }
          File.write(input, JSON.generate(document))

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--output",
            output
          )

          expect(status).to be_success, stderr
          goal = JSON.parse(File.read(output)).fetch("goals").fetch(0)
          expect(goal.fetch("goal_confirmation")).to eq("single_or_spread_announcement")
          expect(goal.fetch("goal_confirmation_count")).to eq(0)
          expect(goal.fetch("needs_manual_review")).to be(true)
        end
      end
    end

    context "when Whisper splits or mishears known player names" do
      it "normalizes aliases before deduplicating the goal" do
        Dir.mktmpdir("extract-match-events-spec-") do |directory|
          input = File.join(directory, "transcript.json")
          output = File.join(directory, "events.json")
          document = {
            "transcription" => [
              segment("00:00:10,000", "00:00:11,000", "Wicu asysta, Mi Link gol"),
              segment("00:00:12,000", "00:00:13,000", "Wicu asysta, Milik gol"),
              segment("00:02:00,000", "00:02:01,000", "Max asysta, Czemu gol"),
              segment("00:03:00,000", "00:03:01,000", "Cash asysta, Paczek gol"),
              segment("00:04:00,000", "00:04:01,000", "Wicso asystami, league goal"),
              segment("00:05:00,000", "00:05:01,000", "Mati kesz gol")
            ]
          }
          File.write(input, JSON.generate(document))

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--output",
            output
          )

          expect(status).to be_success, stderr
          result = JSON.parse(File.read(output))
          expect(result.fetch("goals").map { |goal| [ goal["scorer"], goal["assist"] ] }).to eq(
            [
              [ "Milik", "Wicu" ],
              [ "Przemo", "Max" ],
              [ "Płaczek", "Cash" ],
              [ "Milik", "Wicu" ],
              [ "Cash", "Mati" ]
            ]
          )
        end
      end
    end

    context "when a goal call is corrected to an own goal" do
      it "keeps the initial call and attributes the correction to the named player" do
        Dir.mktmpdir("extract-match-events-spec-") do |directory|
          input = File.join(directory, "transcript.json")
          output = File.join(directory, "events.json")
          document = {
            "transcription" => [
              segment("00:00:05,000", "00:00:06,000", "Dobra, start!"),
              segment("00:00:10,000", "00:00:11,000", "Kamil gol"),
              segment("00:00:12,000", "00:00:13,000", "Co? To samobój"),
              segment("00:00:14,000", "00:00:15,000", "Wicu samobój"),
              segment("00:00:16,000", "00:00:17,000", "Wicesamobój")
            ]
          }
          File.write(input, JSON.generate(document))

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--output",
            output
          )

          expect(status).to be_success, stderr
          result = JSON.parse(File.read(output))
          goal = result.fetch("goals").fetch(0)
          expect(goal).to include(
            "type" => "own_goal",
            "goal_type" => "own_goal",
            "own_goal_player" => "Wicu",
            "scorer" => "Wicu",
            "initial_scorer_call" => "Kamil",
            "assist" => nil
          )
          expect(goal.fetch("own_goal_evidence")).not_to be_empty
        end
      end
    end

    context "when the transcript has no match events" do
      it "returns empty event collections" do
        Dir.mktmpdir("extract-match-events-spec-") do |directory|
          input = File.join(directory, "transcript.json")
          output = File.join(directory, "events.json")
          File.write(input, JSON.generate("transcription" => [ segment("00:00:00,000", "00:00:01,000", "Cisza") ]))

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--output",
            output
          )

          expect(status).to be_success, stderr
          result = JSON.parse(File.read(output))
          expect(result.fetch("goals")).to be_empty
          expect(result.fetch("scores")).to be_empty
          expect(result.fetch("captain_candidates")).to be_empty
        end
      end
    end
  end

  def segment(from, to, text)
    { "timestamps" => { "from" => from, "to" => to }, "text" => text }
  end
end
