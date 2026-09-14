require "json"
require "open3"
require "tmpdir"

RSpec.describe "script/match_audio_pipeline.py" do
  let(:script_path) { File.expand_path("../../script/match_audio_pipeline.py", __dir__) }

  describe "argument validation" do
    it "defaults every transcription path to the full large-v3 model" do
      python = <<~PYTHON
        import json
        import sys

        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        print(json.dumps({
          "transcription": str(pipeline.DEFAULT_TRANSCRIPTION_MODEL),
          "batch": str(pipeline.DEFAULT_BATCH_MODEL),
          "verification": str(pipeline.DEFAULT_VERIFICATION_MODEL),
        }))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.expand_path("../../script", __dir__)
      )

      expect(status).to be_success, stderr
      models = JSON.parse(stdout)
      expect(models.values).to all(end_with("/.local/whisper.cpp/models/ggml-large-v3.bin"))
      expect(models.values).not_to include(a_string_including("turbo"))
    end

    it "defaults audio preparation to two workers" do
      python = <<~PYTHON
        import sys

        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        print(pipeline.DEFAULT_PREPARE_WORKERS)
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.expand_path("../../script", __dir__)
      )

      expect(status).to be_success, stderr
      expect(stdout.strip).to eq("2")
    end

    it "does not treat an unmarked existing transcript as a large-v3 result" do
      Dir.mktmpdir("match-audio-pipeline-spec-") do |directory|
        python = <<~PYTHON
          import sys
          from pathlib import Path

          sys.path.insert(0, sys.argv[1])
          from match_audio_pipeline import transcript_matches_model

          output = Path(sys.argv[2])
          model = Path(sys.argv[3])
          output.write_text("{}", encoding="utf-8")
          print(transcript_matches_model(output, model))
        PYTHON

        stdout, stderr, status = Open3.capture3(
          "python3",
          "-c",
          python,
          File.expand_path("../../script", __dir__),
          File.join(directory, "neutral.json"),
          File.join(directory, "ggml-large-v3.bin")
        )

        expect(status).to be_success, stderr
        expect(stdout.strip).to eq("False")
      end
    end

    it "stores one timing entry per recording variant" do
      Dir.mktmpdir("match-audio-pipeline-spec-") do |directory|
        python = <<~PYTHON
          import json
          import sys
          from pathlib import Path

          sys.path.insert(0, sys.argv[1])
          from match_audio_pipeline import write_transcription_timing

          root = Path(sys.argv[2])
          recording = {"id": "match-1", "name": "Meczyk.m4a"}
          model = Path("/models/ggml-large-v3.bin")
          write_transcription_timing(root, recording, "neutral", model, 12.345, "cpu")
          write_transcription_timing(root, recording, "neutral", model, 13.456, "cpu")
          print((root / "transcription_timings.json").read_text())
        PYTHON

        stdout, stderr, status = Open3.capture3(
          "python3",
          "-c",
          python,
          File.expand_path("../../script", __dir__),
          directory
        )

        expect(status).to be_success, stderr
        timings = JSON.parse(stdout)
        expect(timings).to eq(
          [
            {
              "recording_id" => "match-1",
              "recording_name" => "Meczyk.m4a",
              "variant" => "neutral",
              "model_name" => "ggml-large-v3.bin",
              "device" => "cpu",
              "elapsed_seconds" => 13.46
            }
          ]
        )
      end
    end

    context "when the sample duration is invalid" do
      it "rejects the request before processing audio" do
        _stdout, stderr, status = Open3.capture3(
          "python3",
          script_path,
          "--source",
          Dir.tmpdir,
          "--sample-seconds",
          "0"
        )

        expect(status).not_to be_success
        expect(stderr).to include("--sample-seconds musi być większe od zera")
      end
    end

    context "when the prepare worker count is invalid" do
      it "rejects zero workers before processing audio" do
        _stdout, stderr, status = Open3.capture3(
          "python3",
          script_path,
          "--source",
          Dir.tmpdir,
          "--prepare-workers",
          "0"
        )

        expect(status).not_to be_success
        expect(stderr).to include("--prepare-workers musi być większe od zera")
      end
    end

    context "when the source directory does not exist" do
      it "reports the missing directory" do
        missing = File.join(Dir.tmpdir, "missing-match-audio-source")

        _stdout, stderr, status = Open3.capture3(
          "python3",
          script_path,
          "--source",
          missing,
          "--stage",
          "collect"
        )

        expect(status).not_to be_success
        expect(stderr).to include("nie znaleziono katalogu źródłowego")
      end
    end

    context "when only collecting files" do
      it "does not require local transcription models" do
        Dir.mktmpdir("match-audio-pipeline-spec-") do |directory|
          source = File.join(directory, "Downloads")
          output = File.join(directory, "tmp")
          Dir.mkdir(source)

          stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            "--source",
            source,
            "--output-root",
            output,
            "--date",
            "2026-09-13",
            "--stage",
            "collect",
            "--model",
            File.join(directory, "missing-batch.bin"),
            "--verification-model",
            File.join(directory, "missing-verification.bin")
          )

          expect(status).to be_success, stderr
          expect(stdout).to include("Zebrano 0 nagrań")
        end
      end
    end
  end


  describe "parallel audio preparation" do
    it "prepares every recording with its selected profile" do
      python = <<~PYTHON
        import json
        import sys
        from pathlib import Path

        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        calls = []

        def fake_prepare(recording, run_root, profile, *, force):
          calls.append((recording["id"], profile, force))

        pipeline.prepare_recording = fake_prepare
        pipeline.prepare_recordings(
          [{"id": "meczyk-1"}, {"id": "r-1"}],
          Path(sys.argv[2]),
          {"meczyk-1": "bluetooth", "r-1": "recorder"},
          force=True,
          workers=2,
        )
        print(json.dumps(sorted(calls)))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.expand_path("../../script", __dir__),
        Dir.tmpdir
      )

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to contain_exactly(
        [ "meczyk-1", "bluetooth", true ],
        [ "r-1", "recorder", true ]
      )
    end
  end

  describe "audio-only cleaner recommendation" do
    context "when cleaning only produces a longer transcript" do
      it "keeps the neutral variant because length is not accuracy evidence" do
        Dir.mktmpdir("match-audio-pipeline-spec-") do |directory|
          neutral = File.join(directory, "neutral")
          clean = File.join(directory, "clean")
          timestamp = { "from" => "00:00:10,000", "to" => "00:00:11,000" }
          File.write(
            "#{neutral}.json",
            JSON.generate("transcription" => [ { "timestamps" => timestamp, "text" => "Kamil gol" } ])
          )
          File.write(
            "#{clean}.json",
            JSON.generate(
              "transcription" => [
                {
                  "timestamps" => timestamp,
                  "text" => "Kamil gol i bardzo dużo dodatkowych słów"
                }
              ]
            )
          )
          recording = JSON.generate(
            "id" => "match-1",
            "profile" => "bluetooth",
            "source_type" => "meczyk",
            "neutral_transcript" => neutral,
            "clean_transcript" => clean
          )
          python = <<~PYTHON
            import json
            import sys
            from pathlib import Path
            sys.path.insert(0, sys.argv[3])
            from match_audio_pipeline import analyze_recording
            print(json.dumps(analyze_recording(json.loads(sys.argv[1]), Path(sys.argv[2]))))
          PYTHON

          stdout, stderr, status = Open3.capture3(
            "python3",
            "-c",
            python,
            recording,
            directory,
            File.dirname(script_path)
          )

          expect(status).to be_success, stderr
          result = JSON.parse(stdout)
          expect(result.fetch("recommended_variant")).to eq("neutral")
          expect(result.fetch("recommendation_reason")).to eq("no_audio_based_advantage")
        end
      end
    end

    context "when cleaning reveals an additional goal announcement" do
      it "selects the cleaned variant" do
        Dir.mktmpdir("match-audio-pipeline-spec-") do |directory|
          neutral = File.join(directory, "neutral")
          clean = File.join(directory, "clean")
          first = { "from" => "00:00:10,000", "to" => "00:00:11,000" }
          second = { "from" => "00:03:10,000", "to" => "00:03:11,000" }
          File.write(
            "#{neutral}.json",
            JSON.generate("transcription" => [ { "timestamps" => first, "text" => "Kamil gol" } ])
          )
          File.write(
            "#{clean}.json",
            JSON.generate(
              "transcription" => [
                { "timestamps" => first, "text" => "Kamil gol" },
                { "timestamps" => second, "text" => "Daniel gol" }
              ]
            )
          )
          recording = JSON.generate(
            "id" => "match-1",
            "profile" => "bluetooth",
            "source_type" => "meczyk",
            "neutral_transcript" => neutral,
            "clean_transcript" => clean
          )
          python = <<~PYTHON
            import json
            import sys
            from pathlib import Path
            sys.path.insert(0, sys.argv[3])
            from match_audio_pipeline import analyze_recording
            print(json.dumps(analyze_recording(json.loads(sys.argv[1]), Path(sys.argv[2]))))
          PYTHON

          stdout, stderr, status = Open3.capture3(
            "python3",
            "-c",
            python,
            recording,
            directory,
            File.dirname(script_path)
          )

          expect(status).to be_success, stderr
          result = JSON.parse(stdout)
          expect(result.fetch("recommended_variant")).to eq("clean")
          expect(result.fetch("recommendation_reason")).to eq("more_detected_goals")
        end
      end
    end
  end

  describe "match report facts" do
    it "converts a Meczyk filename and recording offset into match time" do
      python = <<~PYTHON
        import json
        import sys
        from datetime import date
        from zoneinfo import ZoneInfo
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        timezone = ZoneInfo("Europe/Warsaw")
        recording = pipeline.parse_meczyk_recording_start(
            "Meczyk-13 wrz 2026 o 10:00.m4a",
            timezone,
        )
        match = pipeline.absolute_recording_time(
            {"name": "Meczyk-13 wrz 2026 o 10:00.m4a", "source_type": "meczyk"},
            358.410,
            date(2026, 9, 13),
            timezone,
        )
        print(json.dumps({"recording": recording.isoformat(), "match": match.isoformat()}))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result.fetch("recording")).to start_with("2026-09-13T10:00:00")
      expect(result.fetch("match")).to start_with("2026-09-13T10:05:58.410")
    end

    it "marks an audio end message differently from a recording boundary" do
      python = <<~PYTHON
        import json
        import sys
        from datetime import date
        from zoneinfo import ZoneInfo
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        def event(goals, ends):
            return {
                "goals": goals,
                "scores": [],
                "match_starts": [{
                    "recording_seconds": 10.0,
                    "evidence": {"from": "00:00:10,000", "to": "00:00:11,000", "text": "Start"},
                }],
                "match_ends": ends,
                "roster_candidates": [],
                "captain_candidates": [],
            }

        goal = {
            "scorer": "Kamil",
            "assist": None,
            "recording_seconds": 20.0,
            "match_seconds": 10.0,
            "match_minute": 1,
            "confidence": "medium",
            "evidence": [{"from": "00:00:20,000", "to": "00:00:21,000", "text": "Kamil gol"}],
        }
        confirmed_end = [{
            "recording_seconds": 30.0,
            "evidence": {"from": "00:00:30,000", "to": "00:00:31,000", "text": "Koniec"},
        }]
        recordings = [
            {
                "id": "confirmed",
                "name": "Meczyk-13 wrz 2026 o 10:00.m4a",
                "source_type": "meczyk",
                "audio": {"duration": 60.0},
            },
            {
                "id": "estimated",
                "name": "Meczyk-13 wrz 2026 o 11:00.m4a",
                "source_type": "meczyk",
                "audio": {"duration": 60.0},
            },
        ]
        analyses = [
            {"id": "confirmed", "recommended_variant": "neutral", "variants": {"neutral": {"events": event([goal], confirmed_end)}, "clean": {"events": event([goal], confirmed_end)}}},
            {"id": "estimated", "recommended_variant": "neutral", "variants": {"neutral": {"events": event([goal], [])}, "clean": {"events": event([goal], [])}}},
        ]
        summaries = pipeline.build_match_summaries(
            date(2026, 9, 13),
            recordings,
            [],
            analyses,
            ZoneInfo("Europe/Warsaw"),
        )
        print(json.dumps({item["id"]: item["end"]["status"] for item in summaries}))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to eq(
        "confirmed" => "confirmed_audio",
        "estimated" => "estimated_recording_boundary"
      )
    end

    it "keeps organizational recordings out of the match list" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        empty = {"goals": [], "scores": [], "match_starts": [], "match_ends": [], "roster_candidates": [{"text": "skład"}], "captain_candidates": []}
        match = {"goals": [{"scorer": "Kamil", "assist": None, "recording_seconds": 20.0, "match_seconds": None, "match_minute": None, "goal_confirmation": "repeated_within_5_seconds", "evidence": [{"text": "Kamil gol"}]}], "scores": [], "match_starts": [{"recording_seconds": 10.0, "evidence": {"text": "Start"}}], "match_ends": [], "roster_candidates": [], "captain_candidates": []}
        recordings = [
            {"id": "org", "name": "Meczyk-13 wrz 2026 o 09:34.m4a", "source_type": "meczyk", "audio": {"duration": 100.0}},
            {"id": "match", "name": "Meczyk-13 wrz 2026 o 10:00.m4a", "source_type": "meczyk", "audio": {"duration": 100.0}},
        ]
        analyses = [
            {"id": "org", "recommended_variant": "neutral", "variants": {"neutral": {"events": empty}, "clean": {"events": empty}}},
            {"id": "match", "recommended_variant": "neutral", "variants": {"neutral": {"events": match}, "clean": {"events": match}}},
        ]
        print(json.dumps({
            "matches": [item["id"] for item in pipeline.build_match_summaries(__import__("datetime").date(2026, 9, 13), recordings, [], analyses)],
            "organizational": [item["id"] for item in pipeline.organizational_recordings(recordings, analyses)],
        }))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to eq(
        "matches" => [ "match" ],
        "organizational" => [ "org" ]
      )
    end

    it "counts only repeated or independently paired goal announcements" do
      python = <<~PYTHON
        import json
        import sys
        from datetime import date
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        def goal(scorer, seconds, confirmation):
            return {
                "scorer": scorer,
                "assist": None,
                "recording_seconds": seconds,
                "match_seconds": seconds - 10,
                "match_minute": 1,
                "goal_confirmation": confirmation,
                "evidence": [{"text": f"{scorer} gol"}],
            }

        events = {
            "goals": [
                goal("Kamil", 20.0, "repeated_within_5_seconds"),
                goal("Cash", 30.0, "single_or_spread_announcement"),
            ],
            "scores": [],
            "match_starts": [{"recording_seconds": 10.0, "evidence": {"text": "Start"}}],
            "match_ends": [],
            "roster_candidates": [],
            "captain_candidates": [],
        }
        recording = {"id": "match", "name": "Meczyk-13 wrz 2026 o 10:00.m4a", "source_type": "meczyk", "audio": {"duration": 60.0}}
        analysis = {"id": "match", "recommended_variant": "neutral", "variants": {"neutral": {"events": events}, "clean": {"events": events}}}
        summary = pipeline.build_match_summaries(date(2026, 9, 13), [recording], [], [analysis])[0]
        print(json.dumps({"accepted": [goal["scorer"] for goal in summary["goals"]], "pending": [goal["scorer"] for goal in summary["pending_goals"]]}))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to eq(
        "accepted" => [ "Kamil" ],
        "pending" => [ "Cash" ]
      )
    end

    it "creates listenable links for manual-review goal candidates" do
      Dir.mktmpdir("match-audio-pipeline-spec-") do |directory|
        python = <<~PYTHON
          import json
          import sys
          from pathlib import Path
          sys.path.insert(0, sys.argv[1])
          import match_audio_pipeline as pipeline

          def fake_run(command, log_path):
              output = Path(command[-1])
              output.parent.mkdir(parents=True, exist_ok=True)
              output.touch()
              return True

          pipeline.run_logged = fake_run
          root = Path(sys.argv[2])
          summary = {
              "id": "match-1",
              "match_number": 1,
              "goals": [],
              "pending_goals": [{
                  "scorer": "Kamil",
                  "recording_seconds": 20.0,
                  "review_source_id": "match-1",
                  "review_source_role": "meczyk",
                  "review_variant": "neutral",
                  "automatic_count_reason": "single_or_spread_announcement",
                  "evidence": [{"text": "Kamil gol"}],
              }],
              "pending_recorder_goals": [],
          }
          recordings = [{"id": "match-1", "neutral_path": "/tmp/neutral.wav", "audio": {"duration": 60.0}}]
          pipeline.create_goal_review_clips([summary], recordings, root, force=True)
          index = pipeline.assign_review_numbers([summary])
          manual_review = pipeline.build_manual_review([summary], {})
          print(json.dumps({"review": summary["manual_review_goals"][0], "index": index, "manual_review": manual_review}, ensure_ascii=False))
        PYTHON

        stdout, stderr, status = Open3.capture3(
          "python3",
          "-c",
          python,
          File.dirname(script_path),
          directory
        )

        expect(status).to be_success, stderr
        result = JSON.parse(stdout)
        expect(result.dig("review", "status")).to eq("ready")
        expect(result.dig("review", "clip_link")).to eq("manual_review/match-01-meczyk-01-kamil.m4a")
        expect(result.dig("review", "review_number")).to eq(1)
        expect(result.dig("index", 0, "number")).to eq(1)
        expect(result.fetch("manual_review").join).to include("klip 1: odsłuchaj fragment](manual_review/match-01-meczyk-01-kamil.m4a)")
      end
    end

    it "applies user confirmations by merging duplicates and adding confirmed goals" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        summary = {
            "match_number": 2,
            "meczyk_goal_count": 1,
            "goals": [{
                "scorer": "Cash",
                "assist": "Mati",
                "type": "goal",
                "evidence_by_source": {"meczyk": [{"text": "Cash gol"}]},
            }],
            "pending_goals": [],
            "pending_recorder_goals": [
                {
                    "scorer": "T-Cash",
                    "assist": None,
                    "type": "goal",
                    "review_source_id": "r-2",
                    "review_source_role": "recorder",
                    "review_clip": {"clip_link": "manual_review/cash.m4a"},
                    "evidence": [{"text": "Mati cash goal"}],
                },
                {
                    "scorer": "Kamil",
                    "assist": None,
                    "type": "own_goal",
                    "match_minute": 28,
                    "review_source_id": "r-2",
                    "review_source_role": "recorder",
                    "review_clip": {"clip_link": "manual_review/own-goal.m4a"},
                    "evidence": [{"text": "Kamil gol. Samobój."}],
                },
            ],
        }
        confirmations = [
            {"match_number": 2, "clip_link": "manual_review/cash.m4a", "resolution": "duplicate_existing_goal", "scorer": "Cash", "assist": "Mati"},
            {"match_number": 2, "clip_link": "manual_review/own-goal.m4a", "resolution": "new_goal", "scorer": "Wicu", "type": "own_goal", "assist": None},
        ]
        pipeline.apply_manual_confirmations([summary], confirmations)
        print(json.dumps({
            "count": summary["meczyk_goal_count"],
            "scorers": [goal["scorer"] for goal in summary["goals"]],
            "pending": summary["pending_recorder_goals"],
            "statuses": [goal.get("manual_confirmation_status") for goal in summary["goals"]],
        }, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result.fetch("count")).to eq(2)
      expect(result.fetch("scorers")).to contain_exactly("Cash", "Wicu")
      expect(result.fetch("pending")).to be_empty
      expect(result.fetch("statuses")).to contain_exactly("confirmed_by_user", "confirmed_by_user")
    end

    it "does not apply a confirmation to the first pending goal from the same source" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        summary = {
            "match_number": 3,
            "meczyk_goal_count": 0,
            "goals": [],
            "pending_goals": [
                {
                    "scorer": "Kamil (Marcelo)",
                    "assist": "Damian",
                    "recording_seconds": 483.0,
                    "review_source_id": "meczyk-3",
                    "review_source_role": "meczyk",
                    "review_clip": {"status": "clip_failed"},
                    "evidence": [{"text": "Kamil gol"}],
                },
                {
                    "scorer": "Dominik",
                    "assist": "Płaczek",
                    "recording_seconds": 1553.0,
                    "review_source_id": "meczyk-3",
                    "review_source_role": "meczyk",
                    "review_clip": {"status": "ready"},
                    "evidence": [{"text": "Płaczek asysta, Dominik gol"}],
                },
            ],
            "pending_recorder_goals": [],
        }
        confirmations = [{
            "match_number": 3,
            "source_id": "meczyk-3",
            "resolution": "new_goal",
            "scorer": "Dominik",
            "assist": "Płaczek",
        }]
        pipeline.apply_manual_confirmations([summary], confirmations)
        print(json.dumps({
            "goals": [(goal["scorer"], goal["recording_seconds"]) for goal in summary["goals"]],
            "pending": [(goal["scorer"], goal["recording_seconds"]) for goal in summary["pending_goals"]],
            "errors": summary["manual_confirmation_errors"],
        }, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result.fetch("goals")).to eq([ [ "Dominik", 1553.0 ] ])
      expect(result.fetch("pending")).to eq([ [ "Kamil (Marcelo)", 483.0 ] ])
      expect(result.fetch("errors")).to be_empty
    end

    it "uses the unique no-assist goal when a duplicate confirmation omits the assist" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        summary = {
            "match_number": 1,
            "goals": [
                {"scorer": "Baca", "assist": "Max", "recording_seconds": 100.0},
                {"scorer": "Baca", "assist": None, "recording_seconds": 200.0},
            ],
            "pending_goals": [],
            "pending_recorder_goals": [],
        }
        confirmations = [{
            "match_number": 1,
            "resolution": "duplicate_existing_goal",
            "scorer": "Baca",
            "assist": None,
        }]
        pipeline.apply_manual_confirmations([summary], confirmations)
        print(json.dumps({
            "statuses": [goal.get("manual_confirmation_status") for goal in summary["goals"]],
            "errors": summary["manual_confirmation_errors"],
        }, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result.fetch("statuses")).to eq([ nil, "confirmed_by_user" ])
      expect(result.fetch("errors")).to be_empty
    end

    it "keeps an uncertain assist out of the confirmed goal while preserving the candidate" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        summary = {
            "match_number": 2,
            "meczyk_goal_count": 1,
            "goals": [{
                "scorer": "Cash",
                "assist": "Mati",
                "recording_seconds": 684.5,
                "type": "goal",
            }],
            "pending_goals": [],
            "pending_recorder_goals": [{
                "scorer": "Cash",
                "assist": None,
                "type": "goal",
                "recording_seconds": 684.5,
                "review_source_id": "r-2",
                "review_source_role": "recorder",
                "review_clip": {"clip_link": "manual_review/cash.m4a"},
                "evidence": [{"text": "Mati cash goal"}],
            }],
        }
        confirmations = [{
            "match_number": 2,
            "clip_link": "manual_review/cash.m4a",
            "resolution": "duplicate_existing_goal",
            "scorer": "Cash",
            "assist": None,
            "assist_candidate": "Mati",
            "assist_status": "needs_manual_review",
            "recording_seconds": 684.5,
            "assist_review": {"clips": [{"number": 6, "clip_link": "manual_review/06.m4a"}]},
        }]
        pipeline.apply_manual_confirmations([summary], confirmations)
        goal = summary["goals"][0]
        print(json.dumps({
            "assist": goal.get("assist"),
            "candidate": goal.get("assist_candidates"),
            "status": goal.get("assist_status"),
            "review": pipeline.build_manual_review([summary], {}).pop(),
        }, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result.fetch("assist")).to be_nil
      expect(result.fetch("candidate")).to eq([ "Mati" ])
      expect(result.fetch("status")).to eq("manual_review_required")
      expect(result.fetch("review")).to include("klip 6")
    end

    it "records a user-confirmed goal without an assist" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        summary = {
            "match_number": 2,
            "meczyk_goal_count": 1,
            "goals": [{"scorer": "Cash", "assist": "Mati", "recording_seconds": 684.5, "type": "goal"}],
            "pending_goals": [],
            "pending_recorder_goals": [{
                "scorer": "Cash",
                "assist": None,
                "recording_seconds": 684.5,
                "review_source_id": "r-2",
                "review_source_role": "recorder",
                "review_clip": {"clip_link": "manual_review/cash.m4a"},
                "evidence": [{"text": "Mati cash goal"}],
            }],
        }
        pipeline.apply_manual_confirmations([summary], [{
            "match_number": 2,
            "clip_link": "manual_review/cash.m4a",
            "resolution": "duplicate_existing_goal",
            "scorer": "Cash",
            "assist": None,
            "assist_status": "confirmed_no_assist",
            "recording_seconds": 684.5,
        }])
        goal = summary["goals"][0]
        print(json.dumps({"assist": goal.get("assist"), "status": goal.get("assist_status")}, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result).to eq("assist" => nil, "status" => "confirmed_no_assist")
    end

    it "infers 5:3 from eight goals only after the five-goal rule is confirmed" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        def summary():
            return {"match_number": 1, "goals": [{} for _ in range(8)], "final_score": None}

        confirmed = summary()
        pipeline.infer_scores_from_rule([confirmed], {"match_rule": {"id": "first_to_five", "status": "confirmed", "description": "do pięciu", "evidence": []}})
        unconfirmed = summary()
        pipeline.infer_scores_from_rule([unconfirmed], {"match_rule": {"id": "first_to_five", "status": "unconfirmed", "description": "do pięciu", "evidence": []}})
        print(json.dumps({"confirmed": confirmed, "unconfirmed": unconfirmed}))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result.dig("confirmed", "final_score")).to eq("5:3")
      expect(result.dig("confirmed", "final_score_source")).to eq("wywnioskowany_z_reguly")
      expect(result.dig("unconfirmed", "final_score")).to be_nil
    end

    it "applies user-confirmed captains and roster identities" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        fragments = [
            {"purpose": "session_roster", "recording_id": "meczyk", "variant": "clean", "model": "ggml-large-v3.bin", "evidence": [{"text": "Rafał Milik, Daniel Żaba, Mati Inter, Baca, Przemo, ja, Damian. A w drugim teamie jest Kamil, Szymon Nowy, Mati Cash, Kamil Nowy, Płaczek, Adrian, Dominik."}]},
            {"purpose": "session_roster", "recording_id": "recorder", "variant": "clean", "model": "ggml-large-v3.bin", "evidence": [{"text": "Rafał Milik, Daniel Żaba, Mati Inter, Baca, Przemo, ja, Damian. A w drugim teamie jest Kamil, Szymon Nowy, Mati Cash, Kamil Nowy, Płaczek, Adrian, Dominik."}]},
        ]
        context = pipeline.build_session_context([], fragments)
        print(json.dumps({
            "captains": context["captains"],
            "members": [member for roster in context["rosters"] for member in roster["members"]],
        }, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result.fetch("captains").map { |captain| captain["name"] }).to eq([ "Wicu", "Piotrek (Cash)" ])
      expect(result.fetch("captains").map { |captain| captain["team_label"] }).to eq(
        [ "Drużyna Wica", "Drużyna Piotrka (Cash)" ]
      )
      members = result.fetch("members").to_h { |member| [ member["raw"], member ] }
      expect(members.fetch("ja")).to include(
        "name" => "Wicu",
        "status" => "resolved",
        "confidence" => "high"
      )
      expect(members.fetch("Mati/Cash")).to include(
        "name" => "Piotrek (Cash)",
        "alias" => "Cash",
        "status" => "resolved"
      )
      expect(members.fetch("Kamil Nowy")).to include(
        "name" => "Kamil (Barcelona)",
        "alias" => "Barcelona",
        "status" => "resolved"
      )
      expect(members.fetch("Kamil")).to include("name" => "Kamil", "alias" => "Marcelo")
      expect(members.fetch("Rafał")).to include("name" => "Rafał (Rafik)", "alias" => "Rafik")
      expect(members.fetch("Milik")).to include("name" => "Marcin (Milik)", "alias" => "Milik")
      expect(members.fetch("Szymon Nowy")).to include("name" => "Szymon (Koksu)", "alias" => "Koksu")
      expect(members.fetch("Adrian/Adi")).to include("name" => "Adi")
      expect(members.fetch("Damian")).to include("name" => "Damian", "source" => a_string_including("Piotrka"))
    end

    it "records the user-confirmed operator of recorder audio" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        recordings = [{"id": "r-1", "source_type": "recorder"}]
        context = pipeline.build_session_context(recordings, [])
        print(json.dumps(context["recording_operator"], ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to eq(
        "name" => "Wicu",
        "confidence" => "high",
        "source" => "informacja użytkownika"
      )
    end

    it "uses the recorder identity to resolve an otherwise unnamed own-goal correction" do
      python = <<~PYTHON
        import json
        import sys
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        goal = {
            "type": "goal",
            "scorer": "Kamil",
            "assist": None,
            "evidence": [{"text": "Kamil gol"}],
            "own_goal_evidence": [{"text": "samobój"}],
        }
        events = {"goals": [goal]}
        analyses = [{"id": "r-1", "variants": {"neutral": {"events": events}, "clean": {"events": events}}}]
        recordings = [{"id": "r-1", "source_type": "recorder", "recorded_by": {"name": "Wicu"}}]
        pipeline.apply_recorder_identity_to_own_goals(recordings, analyses)
        print(json.dumps(goal, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to include(
        "type" => "own_goal",
        "scorer" => "Wicu",
        "own_goal_player" => "Wicu",
        "initial_scorer_call" => "Kamil"
      )
    end

    it "renders a complete Markdown report and preserves the JSON report contract" do
      python = <<~PYTHON
        import json
        import sys
        from datetime import date
        sys.path.insert(0, sys.argv[1])
        import match_audio_pipeline as pipeline

        summary = {
            "match_number": 1,
            "date": "2026-09-13",
            "recording_name": "Meczyk-13 wrz 2026 o 10:00.m4a",
            "pair_id": "pair-01",
            "pair_verification": "confirmed",
            "meczyk_variant": "neutral",
            "recorder_variant": "clean",
            "meczyk_goal_count": 1,
            "recorder_goal_count": 1,
            "final_score": "1:0",
            "final_score_source": "wypowiedziany",
            "final_score_confidence": "high",
            "start": {"time": "10:05:58", "status": "confirmed_audio", "source": "komunikat audio"},
            "end": {"time": "10:10:00", "status": "estimated_recording_boundary", "source": "granica końca nagrania"},
            "goals": [{"match_minute": 1, "scorer": "Kamil", "assist": None, "confidence": "high", "confirmed_by_both_recordings": True, "evidence_by_source": {"meczyk": [{"text": "Kamil gol"}], "recorder": [{"text": "Kamil gol"}]}}],
        }
        context = {"roster_verification": {"status": "verified_large_v3", "model": "ggml-large-v3.bin"}, "rosters": [{"label": "Drużyna 1", "members": []}], "captains": [{"team": "team_1", "label": "kapitan nieustalony", "confidence": "not_established", "source": "brak komunikatu"}], "match_rule": {"description": "gra do pięciu", "status": "confirmed", "evidence": []}}
        markdown = pipeline.render_report(date(2026, 9, 13), [], [], [], [], [summary], context, [], ["ręczna weryfikacja"])
        report = {"date": "2026-09-13", "matches": [summary], "session": context, "manual_review": ["ręczna weryfikacja"]}
        json.loads(json.dumps(report, ensure_ascii=False))
        print(json.dumps({"markdown": markdown, "json_keys": sorted(report.keys())}, ensure_ascii=False))
      PYTHON

      stdout, stderr, status = Open3.capture3(
        "python3",
        "-c",
        python,
        File.dirname(script_path)
      )

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      markdown = result.fetch("markdown")
      expect(markdown).to include("## Zestawienie meczów", "## Składy sesji i kapitanowie", "Meczyk/R", "kapitan nieustalony", "Kamil gol")
      expect(result.fetch("json_keys")).to include("date", "matches", "session", "manual_review")
    end
  end
end
