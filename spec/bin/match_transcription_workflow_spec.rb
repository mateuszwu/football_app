require "json"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "script/match_transcription_workflow.py" do
  let(:script_path) { File.expand_path("../../script/match_transcription_workflow.py", __dir__) }

  it "selects only Meczyk recordings by the date in their filename" do
    Dir.mktmpdir("match-transcription-workflow-spec-") do |directory|
      source = File.join(directory, "Downloads")
      FileUtils.mkdir_p(source)
      selected = File.join(source, "Meczyk-20 wrz 2026 o 09:56.m4a")
      ignored_recorder = File.join(source, "R20260920-095600.MP3")
      ignored_text = File.join(source, "Meczyk-20 wrz 2026 o 10:54.txt")
      ignored_date = File.join(source, "Meczyk-19 wrz 2026 o 10:54.m4a")
      [ selected, ignored_recorder, ignored_text, ignored_date ].each { |path| File.write(path, "audio") }
      gps = File.join(source, "6aa-test.json")
      File.write(gps, JSON.generate(device_log("2026-09-20T10:00:00+02:00")))
      players = File.join(directory, "players.json")
      File.write(players, JSON.generate("players" => [ { "name" => "Wicu" } ]))

      stdout, stderr, status = Open3.capture3(
        "python3", script_path,
        "--source", source,
        "--output-root", File.join(directory, "isolated"),
        "--date", "2026-09-20",
        "--players-file", players,
        "--skip-transcription",
        "--skip-analysis-thread"
      )

      expect(status).not_to be_success
      expect(stderr).to include("brak transcriptu")
      expect(stdout).to include("Pobrano dane z download (Meczyk-20 wrz 2026 o 09:56.m4a)")
      expect(stdout).not_to include("R20260920-095600.MP3")
    end
  end

  it "builds a direct full-model transcription command without cleaning" do
    python = <<~PYTHON
      import sys
      sys.path.insert(0, sys.argv[1])
      from match_transcription_workflow import build_transcription_command
      print(" ".join(build_transcription_command(
        "/tools/whisper-cli", "/models/ggml-large-v3.bin", "/models/vad.bin",
        "/tmp/input.wav", "/tmp/output", threads=8, cpu=False
      )))
    PYTHON

    stdout, stderr, status = Open3.capture3(
      "python3", "-c", python, File.expand_path("../../script", __dir__)
    )

    expect(status).to be_success, stderr
    expect(stdout).to include("ggml-large-v3.bin", "--vad", "-otxt", "-osrt", "-oj")
    expect(stdout).not_to include("clean_audio", "adeclick", "afftdn", "loudnorm")
  end

  it "renders the requested event table and preserves uncertain audio links" do
    python = <<~PYTHON
      import sys
      sys.path.insert(0, sys.argv[1])
      from match_transcription_workflow import render_report
      print(render_report({
        "session_date": "2026-09-20",
        "matches": [{
          "match_number": 1,
          "start_datetime": "2026-09-20T10:11:42+02:00",
          "end_datetime": None,
          "teams": [{"name": "Wicu", "captain": "Wicu", "goalkeeper": "Piotrek (Bramkarz)", "players": ["Wicu"]}],
          "events": [{"real_time": "10:15:00", "match_minute": 3, "event_type": "gol", "scorer": None, "assistant": None, "confidence": "niepewne", "goal_source": "gps_bez_transkrypcji", "notes": "brak imienia", "audio_to_verify": "/tmp/clip.mp3"}]
        }],
        "manual_review": ["Mecz 1: potwierdź strzelca"]
      }))
    PYTHON

    stdout, stderr, status = Open3.capture3(
      "python3", "-c", python, File.expand_path("../../script", __dir__)
    )

    expect(status).to be_success, stderr
    expect(stdout).to include("Mecz #1", "Klasyfikacja gola", "GPS bez transkrypcji", "Czas rzeczywisty", "niepewne", "![odsłuchaj](/tmp/clip.mp3)")
    expect(stdout).to include("Mecz 1: potwierdź strzelca")
  end

  it "creates MP3 review clips with Codex-compatible audio embedding" do
    python = <<~PYTHON
      import json
      import sys
      import tempfile
      from pathlib import Path

      sys.path.insert(0, sys.argv[1])
      import match_transcription_workflow as workflow

      commands = []

      def fake_run(command, cwd, check):
          commands.append(command)
          Path(command[-1]).touch()

      workflow.subprocess.run = fake_run
      report = {
          "recordings": [{
              "id": "mecz-1",
              "path": "/tmp/mecz.m4a",
              "recording_start": "2026-09-20T10:00:00+02:00"
          }],
          "gps": [{
              "events": [
                  {"timestamp": "2026-09-20T10:00:12+02:00", "event_type": "GOAL_MY"},
                  {"timestamp": "2026-09-20T10:00:30+02:00", "event_type": "GOAL_THEM"}
              ]
          }],
          "matches": [{
              "match_number": 1,
              "start_datetime": "2026-09-20T10:00:00+02:00",
              "end_datetime": "2026-09-20T10:10:00+02:00",
              "events": [{
                  "event_type": "gol",
                  "goal_source": source,
                  "confidence": "pewne",
                  "needs_audio_review": False,
                  "recording_id": "mecz-1",
                  "recording_seconds": seconds
              } for source, seconds in [
                  ("gps_i_transkrypcja", 12),
                  ("gps_bez_transkrypcji", 30),
                  ("transkrypcja_bez_gps", 48)
              ]
              ]
          }]
      }

      with tempfile.TemporaryDirectory() as directory:
          stale_path = Path(directory) / "analysis" / "review_audio" / "stale.mp3"
          stale_path.parent.mkdir(parents=True)
          stale_path.touch()
          decoded_path = Path(directory) / "decoded" / "mecz-1.wav"
          decoded_path.parent.mkdir(parents=True)
          decoded_path.touch()
          workflow.create_audio_review_clips(report, Path(directory))
          print(json.dumps({
              "audio": [event["audio_to_verify"] for event in report["matches"][0]["events"]],
              "commands": commands,
              "recording_seconds": [event["recording_seconds"] for event in report["matches"][0]["events"]],
              "audio_event_source": [event["audio_event_source"] for event in report["matches"][0]["events"]],
              "stale_exists": stale_path.exists(),
              "decoded_input": all(str(decoded_path) in command for command in commands)
          }))
    PYTHON

    stdout, stderr, status = Open3.capture3(
      "python3", "-c", python, File.expand_path("../../script", __dir__)
    )

    expect(status).to be_success, stderr
    payload = JSON.parse(stdout.lines.last)
    expect(payload.fetch("audio")).to all(satisfy { |path| expect(path).to end_with(".mp3") })
    expect(payload.fetch("commands").length).to eq(3)
    expect(payload.fetch("commands").all? { |command| command.include?("libmp3lame") }).to be(true)
    expect(payload.fetch("commands").all? { |command| command.include?("-t") && command.include?("45") }).to be(true)
    expect(payload.fetch("commands").all? { |command| command.include?("apad=pad_dur=45") }).to be(true)
    expect(payload.fetch("commands")[0]).to include("-ss", "7.000")
    expect(payload.fetch("commands")[1]).to include("-ss", "25.000")
    expect(payload.fetch("commands")[2]).to include("-ss", "43.000")
    expect(payload.fetch("recording_seconds")).to eq([ 12.0, 30.0, 48.0 ])
    expect(payload.fetch("audio_event_source")).to eq([ "transkrypcja", "gps", "transkrypcja" ])
    expect(payload.fetch("stale_exists")).to be(false)
    expect(payload.fetch("decoded_input")).to be(true)
  end

  def device_log(datetime)
    {
      "DeviceLog" => {
        "Header" => { "DateTime" => datetime },
        "Zapps" => [ {
          "Id" => "footba01",
          "Name" => "Football Match",
          "Channels" => [ { "ChannelId" => 10, "VariableId" => "event_code" } ]
        } ],
        "Samples" => []
      }
    }
  end
end
