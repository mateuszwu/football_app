#!/usr/bin/env python3
"""Prepare a speech recording for transcription with FFmpeg.

The script removes short clicks and clipped peaks, limits the signal to the
speech band, applies moderate stationary-noise reduction, and normalizes
loudness. It deliberately does not remove silence because doing so would make
timestamps in a later transcript disagree with the original recording.
"""

from __future__ import annotations

import argparse
import json
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


PROFILES = {
    "neutral": [],
    "light": [
        "adeclip=w=55:o=75:a=8:t=12",
        "volume=-3dB",
        "adeclick=w=55:o=75:a=2:t=8:b=2",
        "highpass=f=70:poles=2",
        "lowpass=f=7500:poles=2",
        "afftdn=nr=6:nf=-50:tn=1:gs=4",
    ],
    "balanced": [
        "adeclip=w=55:o=75:a=8:t=8",
        "volume=-3dB",
        "adeclick=w=55:o=75:a=2:t=5:b=2",
        "highpass=f=80:poles=2",
        "lowpass=f=7200:poles=2",
        "afftdn=nr=10:nf=-45:tn=1:gs=5",
    ],
    "bluetooth": [
        "adeclip=w=55:o=75:a=8:t=8",
        "volume=-3dB",
        "adeclick=w=55:o=75:a=2:t=5:b=2",
        "highpass=f=80:poles=2",
        "lowpass=f=7200:poles=2",
        "afftdn=nr=10:nf=-45:tn=1:gs=5",
    ],
    "recorder": [
        "highpass=f=70:poles=2",
        "lowpass=f=7500:poles=2",
        "afftdn=nr=4:nf=-55:tn=1:gs=2",
    ],
    "strong": [
        "adeclip=w=55:o=75:a=8:t=6",
        "volume=-3dB",
        "adeclick=w=55:o=75:a=2:t=3:b=4",
        "highpass=f=100:poles=2",
        "lowpass=f=6500:poles=2",
        "afftdn=nr=18:nf=-40:tn=1:gs=10",
    ],
}

SUPPORTED_OUTPUTS = {".flac", ".m4a", ".mp3", ".wav"}


def build_filter_chain(profile: str) -> str:
    filters = [*PROFILES[profile]]
    if profile != "neutral":
        filters.append("loudnorm=I=-18:LRA=9:TP=-1.5")
    filters.extend(
        [
            "aresample=16000",
            "aformat=sample_fmts=s16:channel_layouts=mono",
        ]
    )
    return ",".join(filters)


def codec_arguments(path: Path, *, compressed: bool = False) -> list[str]:
    suffix = path.suffix.lower()
    if suffix == ".wav":
        return ["-c:a", "pcm_s16le"]
    if suffix == ".flac":
        return ["-c:a", "flac", "-compression_level", "8"]
    if suffix == ".mp3":
        bitrate = "64k" if compressed else "96k"
        return ["-c:a", "libmp3lame", "-b:a", bitrate]
    if suffix == ".m4a":
        bitrate = "64k" if compressed else "96k"
        return ["-c:a", "aac", "-b:a", bitrate]

    supported = ", ".join(sorted(SUPPORTED_OUTPUTS))
    raise ValueError(f"Nieobsługiwany format wyjściowy {suffix!r}. Użyj: {supported}.")


def build_command(
    ffmpeg: str,
    input_path: Path,
    output_path: Path,
    profile: str,
    compressed_output: Path | None,
    force: bool,
) -> list[str]:
    overwrite = "-y" if force else "-n"
    command = [
        ffmpeg,
        "-hide_banner",
        "-loglevel",
        "warning",
        "-stats",
        overwrite,
        "-i",
        str(input_path),
    ]
    filter_chain = build_filter_chain(profile)

    if compressed_output is None:
        return [
            *command,
            "-map_metadata",
            "-1",
            "-af",
            filter_chain,
            "-ar",
            "16000",
            "-ac",
            "1",
            *codec_arguments(output_path),
            str(output_path),
        ]

    return [
        *command,
        "-filter_complex",
        f"[0:a]{filter_chain},asplit=2[master][compressed]",
        "-map_metadata",
        "-1",
        "-map",
        "[master]",
        "-ar",
        "16000",
        "-ac",
        "1",
        *codec_arguments(output_path),
        str(output_path),
        "-map_metadata",
        "-1",
        "-map",
        "[compressed]",
        "-ar",
        "16000",
        "-ac",
        "1",
        *codec_arguments(compressed_output, compressed=True),
        str(compressed_output),
    ]


def probe_audio(ffprobe: str, path: Path) -> dict[str, Any]:
    command = [
        ffprobe,
        "-v",
        "error",
        "-select_streams",
        "a:0",
        "-show_entries",
        "format=duration,size:stream=codec_name,sample_rate,channels",
        "-of",
        "json",
        str(path),
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def describe_audio(path: Path, details: dict[str, Any]) -> str:
    stream = details["streams"][0]
    audio_format = details["format"]
    duration = float(audio_format["duration"])
    size_mb = int(audio_format["size"]) / 1_000_000
    return (
        f"{path}: {duration / 60:.1f} min, {size_mb:.1f} MB, "
        f"{stream['codec_name']}, {stream['sample_rate']} Hz, "
        f"{stream['channels']} kanał(y)"
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Czyści nagranie mowy i przygotowuje je do transkrypcji.",
    )
    parser.add_argument("input", type=Path, help="wejściowy plik audio")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="plik wynikowy (domyślnie: INPUT.clean.wav)",
    )
    parser.add_argument(
        "--compressed-output",
        type=Path,
        help="dodatkowy MP3/M4A 64 kb/s, np. do API z limitem rozmiaru",
    )
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILES),
        default="balanced",
        help="siła czyszczenia (domyślnie: balanced)",
    )
    parser.add_argument("--force", action="store_true", help="nadpisz istniejące pliki")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="pokaż polecenie FFmpeg bez przetwarzania",
    )
    parser.add_argument("--ffmpeg", default="ffmpeg", help=argparse.SUPPRESS)
    parser.add_argument("--ffprobe", default="ffprobe", help=argparse.SUPPRESS)
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"Błąd: {message}", file=sys.stderr)
    return 2


def main() -> int:
    arguments = parse_arguments()
    input_path = arguments.input.expanduser().resolve()
    output_path = (
        arguments.output.expanduser().resolve()
        if arguments.output
        else input_path.with_name(f"{input_path.stem}.clean.wav")
    )
    compressed_output = (
        arguments.compressed_output.expanduser().resolve()
        if arguments.compressed_output
        else None
    )

    if not input_path.is_file():
        return fail(f"nie znaleziono pliku: {input_path}")
    if output_path == input_path:
        return fail("plik wyjściowy nie może być plikiem wejściowym")
    if compressed_output in {input_path, output_path}:
        return fail("każdy plik wejściowy i wyjściowy musi mieć inną ścieżkę")
    if output_path.suffix.lower() not in SUPPORTED_OUTPUTS:
        return fail(f"nieobsługiwany format wyjściowy: {output_path.suffix}")
    if compressed_output and compressed_output.suffix.lower() not in {".m4a", ".mp3"}:
        return fail("--compressed-output musi mieć rozszerzenie .mp3 albo .m4a")
    if shutil.which(arguments.ffmpeg) is None:
        return fail("nie znaleziono ffmpeg; na macOS zainstaluj: brew install ffmpeg")
    if not arguments.dry_run and shutil.which(arguments.ffprobe) is None:
        return fail("nie znaleziono ffprobe (jest instalowany razem z FFmpeg)")

    command = build_command(
        arguments.ffmpeg,
        input_path,
        output_path,
        arguments.profile,
        compressed_output,
        arguments.force,
    )
    if arguments.dry_run:
        print(shlex.join(command))
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    if compressed_output:
        compressed_output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Czyszczenie ({arguments.profile})…")
    try:
        subprocess.run(command, check=True)
        print(describe_audio(output_path, probe_audio(arguments.ffprobe, output_path)))
        if compressed_output:
            print(
                describe_audio(
                    compressed_output,
                    probe_audio(arguments.ffprobe, compressed_output),
                )
            )
    except subprocess.CalledProcessError as error:
        return fail(f"FFmpeg zakończył się kodem {error.returncode}")

    print("Gotowe. Oryginalne nagranie nie zostało zmienione.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
