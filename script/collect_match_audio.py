#!/usr/bin/env python3
"""Collect today's match recordings from Downloads into an ignored tmp folder."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path.home() / "Downloads"
DEFAULT_OUTPUT_ROOT = PROJECT_ROOT / "tmp/match_audio"
AUDIO_EXTENSIONS = {".aac", ".flac", ".m4a", ".mp3", ".ogg", ".wav"}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Kopiuje dzisiejsze nagrania Meczyk-* i R* z Downloads do tmp."
        ),
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument(
        "--date",
        help="data YYYY-MM-DD (domyślnie: dzisiaj w podanej strefie)",
    )
    parser.add_argument("--timezone", default="Europe/Warsaw")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"Błąd: {message}", file=sys.stderr)
    return 2


def source_type(path: Path) -> str | None:
    name = path.name.casefold()
    if name.startswith("meczyk-"):
        return "meczyk"
    if name.startswith("r"):
        return "recorder"
    return None


def file_date(path: Path, timezone: ZoneInfo) -> date:
    return datetime.fromtimestamp(path.stat().st_mtime, timezone).date()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def copy_file(source: Path, destination: Path, *, force: bool) -> str:
    if destination.exists():
        if sha256(source) == sha256(destination):
            return "reused"
        if not force:
            raise FileExistsError(
                f"plik docelowy różni się od źródła: {destination}; użyj --force"
            )

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    return "copied"


def discover_audio(source: Path, target_date: date, timezone: ZoneInfo) -> list[Path]:
    return sorted(
        path
        for path in source.iterdir()
        if path.is_file()
        and path.suffix.casefold() in AUDIO_EXTENSIONS
        and source_type(path) is not None
        and file_date(path, timezone) == target_date
    )


def collect(
    source: Path,
    output_root: Path,
    target_date: date,
    timezone: ZoneInfo,
    *,
    force: bool,
    dry_run: bool,
) -> tuple[Path, dict[str, object]]:
    run_root = output_root / target_date.isoformat()
    audio_files = discover_audio(source, target_date, timezone)
    records: list[dict[str, object]] = []

    for audio in audio_files:
        kind = source_type(audio)
        destination = run_root / "inbox/audio" / audio.name
        status = "planned" if dry_run else copy_file(audio, destination, force=force)
        records.append(
            {
                "kind": "audio",
                "source_type": kind,
                "source": str(audio),
                "destination": str(destination),
                "mtime": datetime.fromtimestamp(
                    audio.stat().st_mtime, timezone
                ).isoformat(),
                "size": audio.stat().st_size,
                "sha256": sha256(audio),
                "status": status,
            }
        )

    manifest = {
        "date": target_date.isoformat(),
        "timezone": str(timezone),
        "source": str(source),
        "run_root": str(run_root),
        "audio_count": len(audio_files),
        "files": records,
    }
    manifest_path = run_root / "manifest.json"
    if not dry_run:
        run_root.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    return manifest_path, manifest


def main() -> int:
    arguments = parse_arguments()
    source = arguments.source.expanduser().resolve()
    output_root = arguments.output_root.expanduser().resolve()

    if not source.is_dir():
        return fail(f"nie znaleziono katalogu źródłowego: {source}")

    try:
        timezone = ZoneInfo(arguments.timezone)
    except ZoneInfoNotFoundError:
        return fail(f"nieznana strefa czasowa: {arguments.timezone}")

    try:
        target_date = (
            date.fromisoformat(arguments.date)
            if arguments.date
            else datetime.now(timezone).date()
        )
    except ValueError:
        return fail("--date musi mieć format YYYY-MM-DD")

    try:
        manifest_path, manifest = collect(
            source,
            output_root,
            target_date,
            timezone,
            force=arguments.force,
            dry_run=arguments.dry_run,
        )
    except (FileExistsError, OSError) as error:
        return fail(str(error))

    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    if not arguments.dry_run:
        print(f"Manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
