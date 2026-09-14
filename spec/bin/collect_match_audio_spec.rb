require "json"
require "fileutils"
require "open3"
require "tmpdir"
require "time"

RSpec.describe "script/collect_match_audio.py" do
  let(:script_path) { File.expand_path("../../script/collect_match_audio.py", __dir__) }

  describe "collecting recordings" do
    context "when matching audio and TXT files were added on the selected date" do
      it "copies only today's audio and ignores all TXT files" do
        Dir.mktmpdir("collect-match-audio-spec-") do |directory|
          source = File.join(directory, "Downloads")
          output = File.join(directory, "tmp")
          FileUtils.mkdir_p(source)
          today = Time.parse("2026-09-13 12:00:00 UTC")
          yesterday = Time.parse("2026-09-12 12:00:00 UTC")
          selected = [ "Meczyk-dzis.m4a", "R20260913-120000.MP3" ]

          selected.each do |name|
            path = File.join(source, name)
            File.write(path, "audio")
            File.utime(today, today, path)
            transcript = path.sub(/\.[^.]+\z/, ".txt")
            File.write(transcript, "tekst")
            File.utime(today, today, transcript)
          end
          old = File.join(source, "Meczyk-wczoraj.m4a")
          File.write(old, "old audio")
          File.utime(yesterday, yesterday, old)
          unrelated = File.join(source, "notatka.mp3")
          File.write(unrelated, "unrelated")
          File.utime(today, today, unrelated)

          stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            "--source",
            source,
            "--output-root",
            output,
            "--date",
            "2026-09-13",
            "--timezone",
            "UTC"
          )

          expect(status).to be_success, stderr
          run_root = File.join(output, "2026-09-13")
          expect(Dir.children(File.join(run_root, "inbox/audio"))).to match_array(selected)
          expect(Dir.exist?(File.join(run_root, "inbox/references"))).to be(false)
          manifest = JSON.parse(File.read(File.join(run_root, "manifest.json")))
          expect(manifest.fetch("audio_count")).to eq(2)
          expect(manifest.fetch("files").map { |file| file.fetch("kind") }).to contain_exactly(
            "audio",
            "audio"
          )
          expect(stdout).to include("Manifest:")
        end
      end
    end

    context "when no matching audio was added on the selected date" do
      it "writes an empty manifest without copying unrelated files" do
        Dir.mktmpdir("collect-match-audio-spec-") do |directory|
          source = File.join(directory, "Downloads")
          output = File.join(directory, "tmp")
          FileUtils.mkdir_p(source)
          unrelated = File.join(source, "notes.txt")
          File.write(unrelated, "notes")

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            "--source",
            source,
            "--output-root",
            output,
            "--date",
            "2026-09-13",
            "--timezone",
            "UTC"
          )

          expect(status).to be_success, stderr
          manifest = JSON.parse(File.read(File.join(output, "2026-09-13/manifest.json")))
          expect(manifest.fetch("audio_count")).to eq(0)
          expect(manifest.fetch("files")).to be_empty
        end
      end
    end
  end
end
