require "open3"
require "tmpdir"

RSpec.describe "script/transcribe_audio.py" do
  let(:script_path) { File.expand_path("../../script/transcribe_audio.py", __dir__) }

  describe "command construction" do
    context "with valid Polish audio" do
      it "uses the full large-v3 accuracy settings and creates three output formats" do
        Dir.mktmpdir("transcribe-audio-spec-") do |directory|
          input = File.join(directory, "input.wav")
          output = File.join(File.realpath(directory), "transcript")
          File.write(input, "test audio")

          stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--output",
            output,
            "--duration",
            "30",
            "--dry-run"
          )

          expect(status).to be_success, stderr
          expect(stdout).to include("-l pl", "-bs 5", "-bo 5", "-mc 0", "-d 30000")
          expect(stdout).to include("-otxt", "-osrt", "-oj", "-of #{output}")
          expect(stdout).to include("--vad", "-vt 0.35", "-vspd 100", "-sns")
          expect(stdout).not_to include("--prompt")
          expect(stdout).not_to include(" -ng")
        end
      end
    end

    context "with an unsupported M4A file" do
      it "explains that audio must be cleaned first" do
        Dir.mktmpdir("transcribe-audio-spec-") do |directory|
          input = File.join(directory, "input.m4a")
          File.write(input, "test audio")

          _stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--dry-run"
          )

          expect(status).not_to be_success
          expect(stderr).to include("script/clean_audio.py")
        end
      end
    end

    context "when VAD is explicitly disabled" do
      it "does not pass speech detection arguments" do
        Dir.mktmpdir("transcribe-audio-spec-") do |directory|
          input = File.join(directory, "input.wav")
          File.write(input, "test audio")

          stdout, stderr, status = Open3.capture3(
            "python3",
            script_path,
            input,
            "--no-vad",
            "--dry-run"
          )

          expect(status).to be_success, stderr
          expect(stdout).not_to include("--vad", "-vm", "-vt", "-vspd")
        end
      end
    end
  end
end
