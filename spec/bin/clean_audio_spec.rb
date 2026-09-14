require "json"
require "open3"
require "tmpdir"

RSpec.describe "script/clean_audio.py" do
  let(:script_path) { File.expand_path("../../script/clean_audio.py", __dir__) }

  it "creates a mono 16 kHz WAV and a compressed transcription copy" do
    skip "FFmpeg is not installed" unless system("ffmpeg", "-version", out: File::NULL, err: File::NULL)

    Dir.mktmpdir("clean-audio-spec-") do |directory|
      input = File.join(directory, "input.wav")
      output = File.join(directory, "clean.wav")
      compressed = File.join(directory, "clean.mp3")
      create_test_audio(input)

      _stdout, stderr, status = Open3.capture3(
        "python3",
        script_path,
        input,
        "--output",
        output,
        "--compressed-output",
        compressed
      )

      expect(status).to be_success, stderr
      expect(audio_stream(output)).to include("codec_name" => "pcm_s16le", "sample_rate" => "16000", "channels" => 1)
      expect(audio_stream(compressed)).to include("codec_name" => "mp3", "sample_rate" => "16000", "channels" => 1)
    end
  end

  it "does not allow replacing the source recording" do
    Dir.mktmpdir("clean-audio-spec-") do |directory|
      input = File.join(directory, "input.wav")
      File.write(input, "not audio")

      _stdout, stderr, status = Open3.capture3(
        "python3",
        script_path,
        input,
        "--output",
        input
      )

      expect(status).not_to be_success
      expect(stderr).to include("plik wyjściowy nie może być plikiem wejściowym")
    end
  end

  it "keeps the neutral baseline free from enhancement filters" do
    Dir.mktmpdir("clean-audio-spec-") do |directory|
      input = File.join(directory, "input.wav")
      output = File.join(directory, "neutral.wav")
      File.write(input, "not decoded during a dry run")

      stdout, stderr, status = Open3.capture3(
        "python3",
        script_path,
        input,
        "--output",
        output,
        "--profile",
        "neutral",
        "--dry-run"
      )

      expect(status).to be_success, stderr
      expect(stdout).to include("aresample=16000")
      expect(stdout).not_to include("adeclick", "afftdn", "loudnorm")
    end
  end

  it "uses separate filters for Bluetooth and recorder sources" do
    Dir.mktmpdir("clean-audio-spec-") do |directory|
      input = File.join(directory, "input.wav")
      File.write(input, "not decoded during a dry run")

      bluetooth, bluetooth_error, bluetooth_status = Open3.capture3(
        "python3",
        script_path,
        input,
        "--profile",
        "bluetooth",
        "--dry-run"
      )
      recorder, recorder_error, recorder_status = Open3.capture3(
        "python3",
        script_path,
        input,
        "--profile",
        "recorder",
        "--dry-run"
      )

      expect(bluetooth_status).to be_success, bluetooth_error
      expect(recorder_status).to be_success, recorder_error
      expect(bluetooth).to include("adeclick", "afftdn=nr=10")
      expect(recorder).to include("afftdn=nr=4")
      expect(recorder).not_to include("adeclick", "adeclip")
    end
  end

  def create_test_audio(path)
    _output, status = Open3.capture2e(
      "ffmpeg",
      "-hide_banner",
      "-loglevel",
      "error",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=1000:duration=0.25:sample_rate=16000",
      "-c:a",
      "pcm_s16le",
      path
    )
    raise "Could not create test audio" unless status.success?
  end

  def audio_stream(path)
    output, status = Open3.capture2e(
      "ffprobe",
      "-v",
      "error",
      "-select_streams",
      "a:0",
      "-show_entries",
      "stream=codec_name,sample_rate,channels",
      "-of",
      "json",
      path
    )
    raise output unless status.success?

    JSON.parse(output).fetch("streams").fetch(0)
  end
end
