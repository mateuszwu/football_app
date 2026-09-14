#!/usr/bin/env python3
"""Transcribe Polish speech locally with whisper.cpp and Whisper large-v3."""

from __future__ import annotations

import argparse
import shlex
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WHISPER_CLI = (
    PROJECT_ROOT / ".local/whisper.cpp/build-macos/bin/whisper-cli"
)
DEFAULT_MODEL = PROJECT_ROOT / ".local/whisper.cpp/models/ggml-large-v3.bin"
DEFAULT_VAD_MODEL = (
    PROJECT_ROOT / ".local/whisper.cpp/models/ggml-silero-v6.2.0.bin"
)
SUPPORTED_INPUTS = {".flac", ".mp3", ".ogg", ".wav"}
OUTPUT_EXTENSIONS = ("txt", "srt", "json")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Tworzy lokalną transkrypcję przy użyciu Whisper large-v3.",
    )
    parser.add_argument("input", type=Path, help="oczyszczony plik WAV/FLAC/MP3/OGG")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="bazowa ścieżka wyników bez rozszerzenia",
    )
    parser.add_argument("--language", default="pl", help="kod języka (domyślnie: pl)")
    parser.add_argument("--threads", type=int, default=8, help="liczba wątków CPU")
    parser.add_argument(
        "--duration",
        type=int,
        help="opcjonalny limit testu w sekundach",
    )
    parser.add_argument("--cpu", action="store_true", help="wyłącz akcelerację Metal")
    parser.add_argument(
        "--no-vad",
        action="store_true",
        help="wyłącz wykrywanie mowy (zwiększa ryzyko halucynacji na ciszy)",
    )
    parser.add_argument("--force", action="store_true", help="nadpisz istniejące wyniki")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="pokaż polecenie bez uruchamiania modelu",
    )
    parser.add_argument(
        "--whisper-cli",
        type=Path,
        default=DEFAULT_WHISPER_CLI,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=DEFAULT_MODEL,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--vad-model",
        type=Path,
        default=DEFAULT_VAD_MODEL,
        help=argparse.SUPPRESS,
    )
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"Błąd: {message}", file=sys.stderr)
    return 2


def output_paths(output_base: Path) -> list[Path]:
    return [Path(f"{output_base}.{extension}") for extension in OUTPUT_EXTENSIONS]


def build_command(
    whisper_cli: Path,
    model: Path,
    input_path: Path,
    output_base: Path,
    language: str,
    threads: int,
    duration: int | None,
    cpu: bool,
    vad_model: Path,
    vad: bool,
) -> list[str]:
    command = [
        str(whisper_cli),
        "-m",
        str(model),
        "-f",
        str(input_path),
        "-l",
        language,
        "-t",
        str(threads),
        "-bs",
        "5",
        "-bo",
        "5",
        "-mc",
        "0",
        "-otxt",
        "-osrt",
        "-oj",
        "-of",
        str(output_base),
    ]
    if vad:
        command.extend(
            [
                "--vad",
                "-vm",
                str(vad_model),
                "-vt",
                "0.35",
                "-vspd",
                "100",
                "-vsd",
                "300",
                "-vp",
                "200",
                "-vo",
                "0.20",
                "-sns",
            ]
        )
    if duration is not None:
        command.extend(["-d", str(duration * 1000)])
    if cpu:
        command.append("-ng")
    return command


def main() -> int:
    arguments = parse_arguments()
    input_path = arguments.input.expanduser().resolve()
    output_base = (
        arguments.output.expanduser().resolve()
        if arguments.output
        else input_path.with_name(f"{input_path.stem}-large-v3")
    )
    whisper_cli = arguments.whisper_cli.expanduser().resolve()
    model = arguments.model.expanduser().resolve()
    vad_model = arguments.vad_model.expanduser().resolve()

    if not input_path.is_file():
        return fail(f"nie znaleziono pliku: {input_path}")
    if input_path.suffix.lower() not in SUPPORTED_INPUTS:
        supported = ", ".join(sorted(SUPPORTED_INPUTS))
        return fail(
            f"format {input_path.suffix!r} nie jest obsługiwany; użyj {supported}. "
            "Plik M4A najpierw przetwórz przez script/clean_audio.py."
        )
    if arguments.threads < 1:
        return fail("--threads musi być większe od zera")
    if arguments.duration is not None and arguments.duration < 1:
        return fail("--duration musi być większe od zera")

    results = output_paths(output_base)
    existing = [path for path in results if path.exists()]
    if existing and not arguments.force:
        return fail(
            "wyniki już istnieją: "
            + ", ".join(str(path) for path in existing)
            + "; użyj --force, aby je nadpisać"
        )

    command = build_command(
        whisper_cli,
        model,
        input_path,
        output_base,
        arguments.language,
        arguments.threads,
        arguments.duration,
        arguments.cpu,
        vad_model,
        not arguments.no_vad,
    )
    if arguments.dry_run:
        print(shlex.join(command))
        return 0

    if not whisper_cli.is_file():
        return fail(f"nie znaleziono whisper-cli: {whisper_cli}")
    if not model.is_file():
        return fail(f"nie znaleziono modelu large-v3: {model}")
    if not arguments.no_vad and not vad_model.is_file():
        return fail(f"nie znaleziono modelu VAD: {vad_model}")

    output_base.parent.mkdir(parents=True, exist_ok=True)
    print("Transkrypcja Whisper large-v3…")
    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as error:
        return fail(f"whisper-cli zakończył się kodem {error.returncode}")

    print("Utworzono:")
    for path in results:
        print(f"- {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
