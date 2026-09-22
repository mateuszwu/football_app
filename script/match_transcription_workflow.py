#!/usr/bin/env python3
"""Transcribe Meczyk recordings and delegate match analysis to a new Codex task.

This workflow is intentionally isolated from ``match_audio_pipeline.py``.  It
uses ``tmp/match_transcription_workflow`` and never reads or writes
``tmp/match_audio``.  The source audio is decoded to a neutral WAV only because
whisper.cpp needs a directly readable PCM stream; no denoising or other audio
cleaning is performed.
"""

from __future__ import annotations

import argparse
from datetime import date, datetime, timedelta
import hashlib
import json
import re
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path.home() / "Downloads"
DEFAULT_OUTPUT_ROOT = PROJECT_ROOT / "tmp/match_transcription_workflow"
DEFAULT_WHISPER_CLI = PROJECT_ROOT / ".local/whisper.cpp/build-macos/bin/whisper-cli"
DEFAULT_MODEL = PROJECT_ROOT / ".local/whisper.cpp/models/ggml-large-v3.bin"
DEFAULT_VAD_MODEL = PROJECT_ROOT / ".local/whisper.cpp/models/ggml-silero-v6.2.0.bin"
INSTRUCTIONS_PATH = PROJECT_ROOT / "script/match_analysis_instructions.md"
OUTPUT_SCHEMA_PATH = PROJECT_ROOT / "script/match_analysis_output.schema.json"
SUPPORTED_AUDIO_EXTENSIONS = {".aac", ".flac", ".m4a", ".mp3", ".ogg", ".wav"}
GPS_PREFIX = "6aa"
MECZYK_FILENAME_RE = re.compile(
    r"^meczyk-(?P<day>\d{1,2})\s+(?P<month>[\wąćęłńóśźż]+)\s+"
    r"(?P<year>\d{4})\s+o\s+(?P<hour>\d{1,2}):(?P<minute>\d{2})$",
    re.IGNORECASE,
)
POLISH_MONTHS = {
    "sty": 1,
    "stycz": 1,
    "lut": 2,
    "mar": 3,
    "kwi": 4,
    "maj": 5,
    "cze": 6,
    "lip": 7,
    "sie": 8,
    "wrz": 9,
    "paź": 10,
    "paz": 10,
    "paźdz": 10,
    "lis": 11,
    "gru": 12,
}
DEVICE_EVENT_TYPES = {
    1: "MATCH_START",
    2: "GOAL_MY",
    3: "GOAL_THEM",
    4: "UNDO_GOAL",
    5: "MATCH_END",
}
GOAL_EVENT_TYPES = {"gol", "samobój", "samoboj"}
GOAL_SOURCE_LABELS = {
    "gps_i_transkrypcja": "GPS + transkrypcja",
    "gps_bez_transkrypcji": "GPS bez transkrypcji",
    "transkrypcja_bez_gps": "Transkrypcja bez GPS",
}
GOAL_SOURCES = frozenset(GOAL_SOURCE_LABELS)
GPS_GOAL_SOURCES = frozenset({"gps_i_transkrypcja", "gps_bez_transkrypcji"})
GPS_GOAL_EVENT_TYPES = frozenset({"GOAL_MY", "GOAL_THEM"})
CLIP_LEAD_SECONDS = 5.0
CLIP_DURATION_SECONDS = 45.0


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Nowy, odizolowany workflow: Meczyk-* -> large-v3 -> analiza Codex "
            "-> raport meczowy."
        ),
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--date", help="data YYYY-MM-DD; domyślnie dzisiaj")
    parser.add_argument("--timezone", default="Europe/Warsaw")
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--whisper-cli", type=Path, default=DEFAULT_WHISPER_CLI)
    parser.add_argument("--vad-model", type=Path, default=DEFAULT_VAD_MODEL)
    parser.add_argument("--threads", type=int, default=8)
    parser.add_argument("--cpu", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--skip-analysis-thread",
        action="store_true",
        help="zapisz prompt i materiały, ale nie uruchamiaj Codex exec",
    )
    parser.add_argument(
        "--analysis-result",
        type=Path,
        help="istniejący JSON z wynikiem taska analitycznego; pomija spawn i renderuje raport",
    )
    parser.add_argument(
        "--skip-transcription",
        action="store_true",
        help="użyj istniejących transcriptów w katalogu run; przydatne przy wznowieniu",
    )
    parser.add_argument(
        "--players-file",
        type=Path,
        help="opcjonalny JSON z listą zawodników zamiast Rails runner",
    )
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"Błąd: {message}", file=sys.stderr)
    return 2


def log(message: str) -> None:
    print(message, flush=True)


def slugify(value: str) -> str:
    ascii_value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", ascii_value.casefold()).strip("-")


def parse_meczyk_start(name: str, timezone: ZoneInfo) -> datetime | None:
    match = MECZYK_FILENAME_RE.match(Path(name).stem)
    if match is None:
        return None

    month_name = match.group("month").casefold()
    month = POLISH_MONTHS.get(month_name)
    if month is None:
        month = next(
            (
                number
                for label, number in POLISH_MONTHS.items()
                if month_name.startswith(label)
            ),
            None,
        )
    if month is None:
        return None

    try:
        return datetime(
            int(match.group("year")),
            month,
            int(match.group("day")),
            int(match.group("hour")),
            int(match.group("minute")),
            tzinfo=timezone,
        )
    except ValueError:
        return None


def iso_datetime(value: datetime | None) -> str | None:
    return value.isoformat(timespec="milliseconds") if value else None


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
    """Return only Meczyk recordings whose filename contains target_date."""

    selected: list[Path] = []
    for path in source.iterdir():
        if not path.is_file() or path.suffix.casefold() not in SUPPORTED_AUDIO_EXTENSIONS:
            continue
        recording_start = parse_meczyk_start(path.name, timezone)
        if recording_start is not None and recording_start.date() == target_date:
            selected.append(path)
    return sorted(selected, key=lambda path: (parse_meczyk_start(path.name, timezone), path.name))


def device_log_has_date(path: Path, target_date: date, timezone: ZoneInfo) -> bool:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
        device_log = document.get("DeviceLog", {})
        header_date = str(device_log.get("Header", {}).get("DateTime", ""))
        if header_date:
            parsed = datetime.fromisoformat(header_date.replace("Z", "+00:00"))
            if parsed.astimezone(timezone).date() == target_date:
                return True
        for sample in device_log.get("Samples", []):
            value = sample.get("TimeISO8601") if isinstance(sample, dict) else None
            if not value:
                continue
            parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
            if parsed.astimezone(timezone).date() == target_date:
                return True
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return False
    return False


def discover_gps(source: Path, target_date: date, timezone: ZoneInfo) -> list[Path]:
    selected: list[Path] = []
    for path in source.iterdir():
        if (
            path.is_file()
            and path.suffix.casefold() == ".json"
            and path.name.casefold().startswith(GPS_PREFIX)
            and device_log_has_date(path, target_date, timezone)
        ):
            selected.append(path)
    return sorted(selected)


def collect_inputs(
    source: Path,
    run_root: Path,
    target_date: date,
    timezone: ZoneInfo,
    *,
    force: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    log("Pobieranie danych z download")
    audio_sources = discover_audio(source, target_date, timezone)
    gps_sources = discover_gps(source, target_date, timezone)
    if not audio_sources:
        raise FileNotFoundError(f"nie znaleziono plików Meczyk-* dla {target_date}")
    if not gps_sources:
        raise FileNotFoundError(f"nie znaleziono pliku GPS 6aa*.json dla {target_date}")

    recordings: list[dict[str, Any]] = []
    for index, source_path in enumerate(audio_sources, start=1):
        destination = run_root / "input/audio" / source_path.name
        status = copy_file(source_path, destination, force=force)
        recording_start = parse_meczyk_start(source_path.name, timezone)
        recording = {
            "id": f"match-recording-{index:02d}",
            "sequence": index,
            "name": source_path.name,
            "source": str(source_path),
            "path": str(destination),
            "source_sha256": sha256(source_path),
            "collection_status": status,
            "recording_start": iso_datetime(recording_start),
        }
        recordings.append(recording)
        log(f"Pobrano dane z download ({source_path.name})")

    gps_files: list[dict[str, Any]] = []
    for source_path in gps_sources:
        destination = run_root / "input/gps" / source_path.name
        status = copy_file(source_path, destination, force=force)
        gps_files.append(
            {
                "name": source_path.name,
                "source": str(source_path),
                "path": str(destination),
                "source_sha256": sha256(source_path),
                "collection_status": status,
            }
        )
        log(f"Pobrano dane z download ({source_path.name})")
    return recordings, gps_files


def fetch_players_from_database(players_file: Path | None) -> list[dict[str, Any]]:
    log("Pobieranie listy zawodników")
    if players_file is not None:
        document = json.loads(players_file.read_text(encoding="utf-8"))
        players = document.get("players", document) if isinstance(document, dict) else document
        if not isinstance(players, list):
            raise ValueError("lista zawodników musi być tablicą JSON")
        return players

    ruby = (
        'require "json"; '
        'puts Player.approved.active.order(:name).map { |p| '
        '{ id: p.id, name: p.name, nickname: p.nickname, role_code: p.role_code } '
        '}.to_json'
    )
    result = subprocess.run(
        [str(PROJECT_ROOT / "bin/rails"), "runner", ruby],
        cwd=PROJECT_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Rails runner nie zwrócił listy zawodników")
    try:
        players = json.loads(result.stdout.strip())
    except json.JSONDecodeError as error:
        raise RuntimeError(f"nie można odczytać listy zawodników: {result.stdout}") from error
    if not isinstance(players, list):
        raise ValueError("Rails runner zwrócił nieprawidłową listę zawodników")
    return players


def build_decode_command(input_path: Path, output_path: Path, *, force: bool) -> list[str]:
    return [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y" if force else "-n",
        "-i",
        str(input_path),
        "-ar",
        "16000",
        "-ac",
        "1",
        "-c:a",
        "pcm_s16le",
        str(output_path),
    ]


def build_transcription_command(
    whisper_cli: Path,
    model: Path,
    vad_model: Path,
    input_path: Path,
    output_base: Path,
    *,
    threads: int,
    cpu: bool,
) -> list[str]:
    command = [
        str(whisper_cli),
        "-m",
        str(model),
        "-f",
        str(input_path),
        "-l",
        "pl",
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
    if cpu:
        command.append("-ng")
    return command


def transcript_paths(run_root: Path, recording: dict[str, Any]) -> dict[str, Path]:
    base = run_root / "transcripts" / recording["id"]
    return {extension: Path(f"{base}.{extension}") for extension in ("txt", "srt", "json")}


def transcribe_recording(
    recording: dict[str, Any],
    run_root: Path,
    *,
    model: Path,
    whisper_cli: Path,
    vad_model: Path,
    threads: int,
    cpu: bool,
    force: bool,
) -> dict[str, Any]:
    log(f"Uruchamianie transkrypcji dla ({recording['name']})")
    decoded_path = run_root / "decoded" / f"{recording['id']}.wav"
    output = transcript_paths(run_root, recording)
    decoded_path.parent.mkdir(parents=True, exist_ok=True)
    output["json"].parent.mkdir(parents=True, exist_ok=True)
    command = build_transcription_command(
        whisper_cli,
        model,
        vad_model,
        decoded_path,
        output["json"].with_suffix(""),
        threads=threads,
        cpu=cpu,
    )
    existing = [path for path in output.values() if path.exists()]
    if existing and not force:
        raise FileExistsError(
            "wyniki transkrypcji już istnieją: "
            + ", ".join(str(path) for path in existing)
            + "; użyj --force"
        )
    decode_command = build_decode_command(Path(recording["path"]), decoded_path, force=force)
    transcription_log = run_root / "logs" / f"{recording['id']}.log"
    transcription_log.parent.mkdir(parents=True, exist_ok=True)
    with transcription_log.open("w", encoding="utf-8") as log_stream:
        if force or not decoded_path.exists():
            subprocess.run(
                decode_command,
                cwd=PROJECT_ROOT,
                check=True,
                stdout=log_stream,
                stderr=subprocess.STDOUT,
                text=True,
            )
        try:
            subprocess.run(
                command,
                cwd=PROJECT_ROOT,
                check=True,
                stdout=log_stream,
                stderr=subprocess.STDOUT,
                text=True,
            )
        except subprocess.CalledProcessError:
            if cpu:
                raise
            log("Metal nie uruchomił pełnego modelu; ponawiam transkrypcję na CPU")
            log_stream.write("\nAutomatyczny fallback do CPU po błędzie Metal.\n")
            log_stream.flush()
            subprocess.run(
                build_transcription_command(
                    whisper_cli,
                    model,
                    vad_model,
                    decoded_path,
                    output["json"].with_suffix(""),
                    threads=threads,
                    cpu=True,
                ),
                cwd=PROJECT_ROOT,
                check=True,
                stdout=log_stream,
                stderr=subprocess.STDOUT,
                text=True,
            )
    if not output["json"].is_file():
        raise RuntimeError(f"whisper-cli nie utworzył pliku {output['json']}")
    metadata = {
        "recording_id": recording["id"],
        "source": recording["source"],
        "decoded_input": str(decoded_path),
        "model": str(model),
        "model_name": model.name,
        "cleaning_applied": False,
        "vad_enabled": True,
    }
    output["json"].with_suffix(".metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    recording["transcript"] = {key: str(path) for key, path in output.items()}
    recording["decoded_audio"] = str(decoded_path)
    recording["transcription_log"] = str(transcription_log)
    log(f"Zakończenie transkrypcji dla ({recording['name']})")
    return recording


def gps_summary(gps_files: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    """Extract compact GPS event data for the AI prompt without copying GPS noise."""

    summaries: list[dict[str, Any]] = []
    for file in gps_files:
        path = Path(file["path"])
        document = json.loads(path.read_text(encoding="utf-8"))
        device_log = document.get("DeviceLog", {})
        app = next(
            (
                item
                for item in device_log.get("Zapps", [])
                if item.get("Id") == "footba01" and item.get("Name") == "Football Match"
            ),
            None,
        )
        if not app:
            summaries.append({"file": str(path), "status": "no_football_match_app"})
            continue
        channel = next(
            (
                item
                for item in app.get("Channels", [])
                if item.get("VariableId") == "event_code"
            ),
            None,
        )
        if not channel:
            summaries.append({"file": str(path), "status": "no_event_code_channel"})
            continue
        channel_id = channel.get("ChannelId")
        events: list[dict[str, Any]] = []
        previous_value: Any = object()
        for sample in device_log.get("Samples", []):
            zapp_sample = sample.get("ZappSample") if isinstance(sample, dict) else None
            if not isinstance(zapp_sample, dict) or str(zapp_sample.get("ChannelId")) != str(channel_id):
                continue
            value = int(float(zapp_sample["Value"]))
            if value == previous_value:
                continue
            previous_value = value
            event_code = value // 10
            events.append(
                {
                    "timestamp": sample.get("TimeISO8601"),
                    "value": value,
                    "event_type": DEVICE_EVENT_TYPES.get(event_code, "UNKNOWN"),
                }
            )
        summaries.append(
            {
                "file": str(path),
                "header_datetime": device_log.get("Header", {}).get("DateTime"),
                "duration_seconds": device_log.get("Header", {}).get("Duration"),
                "channel_id": channel_id,
                "event_count": len(events),
                "events": events,
            }
        )
    return summaries


def build_analysis_prompt(
    run_root: Path,
    recordings: list[dict[str, Any]],
    gps_files: list[dict[str, Any]],
    players: list[dict[str, Any]],
) -> str:
    instructions = INSTRUCTIONS_PATH.read_text(encoding="utf-8")
    materials = {
        "run_root": str(run_root),
        "players": str(run_root / "players.json"),
        "gps": [file["path"] for file in gps_files],
        "transcripts": [recording["transcript"]["json"] for recording in recordings],
        "recordings": [
            {
                "id": recording["id"],
                "name": recording["name"],
                "path": recording["path"],
                "recording_start": recording["recording_start"],
                "transcript_json": recording["transcript"]["json"],
            }
            for recording in recordings
        ],
    }
    return (
        f"{instructions.rstrip()}\n\n"
        "## Materiały wejściowe — czytaj bezpośrednio z tych ścieżek\n\n"
        f"```json\n{json.dumps(materials, ensure_ascii=False, indent=2)}\n```\n\n"
        "## Lista zawodników pobrana z bazy\n\n"
        f"Liczba zawodników: {len(players)}. Pełna lista jest w `{run_root / 'players.json'}`.\n\n"
        "## Oczekiwany format odpowiedzi\n\n"
        f"Zwróć wyłącznie JSON zgodny ze schematem `{OUTPUT_SCHEMA_PATH}`. Nie dodawaj Markdown ani komentarza."
        "\n"
    )


def extract_json(text: str) -> dict[str, Any]:
    candidate = text.strip()
    if candidate.startswith("```"):
        candidate = re.sub(r"^```(?:json)?\s*", "", candidate, flags=re.IGNORECASE)
        candidate = re.sub(r"\s*```$", "", candidate)
    try:
        value = json.loads(candidate)
    except json.JSONDecodeError:
        start = candidate.find("{")
        end = candidate.rfind("}")
        if start < 0 or end <= start:
            raise
        value = json.loads(candidate[start : end + 1])
    if not isinstance(value, dict):
        raise ValueError("wynik analizy AI musi być obiektem JSON")
    return value


def spawn_analysis_thread(run_root: Path, prompt_path: Path) -> Path:
    log("Uruchamianie wątku do analizy transkrypcji")
    output_path = run_root / "analysis/ai_analysis.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "codex",
        "exec",
        "--model",
        "gpt-5.6-sol",
        "--config",
        "model_reasoning_effort=xhigh",
        "--sandbox",
        "read-only",
        "--cd",
        str(PROJECT_ROOT),
        "--skip-git-repo-check",
        "--output-schema",
        str(OUTPUT_SCHEMA_PATH),
        "--output-last-message",
        str(output_path),
        "-",
    ]
    with prompt_path.open("r", encoding="utf-8") as prompt_stream:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            stdin=prompt_stream,
            check=False,
            text=True,
        )
    if result.returncode != 0:
        raise RuntimeError(f"wątek analityczny zakończył się kodem {result.returncode}")
    if not output_path.is_file():
        raise RuntimeError(f"wątek analityczny nie utworzył {output_path}")
    return output_path


def seconds_from_value(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str):
        return None
    parts = value.replace(",", ".").split(":")
    try:
        if len(parts) == 3:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
        if len(parts) == 2:
            return int(parts[0]) * 60 + float(parts[1])
        return float(value)
    except ValueError:
        return None


def is_goal_event(event: dict[str, Any]) -> bool:
    event_type = str(event.get("event_type", "")).strip().casefold()
    return event_type in GOAL_EVENT_TYPES


def parse_iso_datetime(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def gps_events_for_match(
    report: dict[str, Any],
    match: dict[str, Any],
) -> list[dict[str, Any]]:
    start = parse_iso_datetime(match.get("start_datetime"))
    end = parse_iso_datetime(match.get("end_datetime"))
    events: list[dict[str, Any]] = []
    for gps_file in report.get("gps", []):
        for event in gps_file.get("events", []):
            timestamp = parse_iso_datetime(event.get("timestamp"))
            if timestamp is None:
                continue
            if start is not None and timestamp < start:
                continue
            if end is not None and timestamp > end:
                continue
            events.append(event)
    return sorted(
        events,
        key=lambda event: parse_iso_datetime(event.get("timestamp")) or datetime.min,
    )


def active_gps_goals_for_match(
    report: dict[str, Any],
    match: dict[str, Any],
) -> list[dict[str, Any]]:
    active_goals: list[dict[str, Any]] = []
    for event in gps_events_for_match(report, match):
        event_type = event.get("event_type")
        if event_type in GPS_GOAL_EVENT_TYPES:
            active_goals.append(event)
        elif event_type == "UNDO_GOAL" and active_goals:
            active_goals.pop()
    return active_goals


def recording_seconds_at_gps_event(
    recording: dict[str, Any],
    gps_event: dict[str, Any],
) -> float:
    recording_start = parse_iso_datetime(recording.get("recording_start"))
    gps_timestamp = parse_iso_datetime(gps_event.get("timestamp"))
    if recording_start is None or gps_timestamp is None:
        raise ValueError("brak poprawnego czasu nagrania lub eventu GPS dla wycinka")
    seconds = (gps_timestamp - recording_start).total_seconds()
    if seconds < 0:
        raise ValueError(
            "event GPS występuje przed początkiem przypisanego nagrania: "
            + str(gps_event.get("timestamp"))
        )
    return seconds


def create_audio_review_clips(report: dict[str, Any], run_root: Path) -> None:
    log("Generowanie plików audio do weryfikacji..")
    clips_root = run_root / "analysis/review_audio"
    if clips_root.exists():
        if not clips_root.is_dir():
            raise ValueError(f"ścieżka na wycinki nie jest katalogiem: {clips_root}")
        shutil.rmtree(clips_root)
    clips_root.mkdir(parents=True, exist_ok=True)
    recordings = {
        item["id"]: item
        for item in report.get("recordings", [])
        if item.get("path")
    }
    for match in report.get("matches", []):
        gps_goals = active_gps_goals_for_match(report, match)
        gps_goal_index = 0
        for index, event in enumerate(match.get("events", []), start=1):
            goal_event = is_goal_event(event)
            if goal_event and event.get("goal_source") not in GOAL_SOURCES:
                raise ValueError(
                    f"gol w meczu {match.get('match_number', '?')} nie ma poprawnego goal_source"
                )
            if not goal_event and event.get("confidence") != "niepewne" and not event.get("needs_audio_review"):
                continue
            recording_id = event.get("recording_id")
            recording = recordings.get(recording_id)
            recording_path = Path(recording["path"]) if recording else None
            gps_event = None
            if goal_event and event.get("goal_source") in GPS_GOAL_SOURCES:
                if gps_goal_index >= len(gps_goals):
                    raise ValueError(
                        f"brak odpowiadającego eventu GPS dla gola w meczu "
                        f"{match.get('match_number', '?')}"
                    )
                gps_event = gps_goals[gps_goal_index]
                gps_goal_index += 1
            recording_seconds = (
                recording_seconds_at_gps_event(recording, gps_event)
                if (
                    event.get("goal_source") == "gps_bez_transkrypcji"
                    and gps_event is not None
                    and recording is not None
                )
                else seconds_from_value(event.get("recording_seconds"))
            )
            if recording is None or recording_path is None or recording_seconds is None:
                if goal_event:
                    raise ValueError(
                        f"gol w meczu {match.get('match_number', '?')} nie ma recording_id/recording_seconds"
                    )
                continue
            clip_name = f"mecz-{match.get('match_number', 'x')}-event-{index:02d}.mp3"
            clip_path = clips_root / clip_name
            start = max(0.0, recording_seconds - CLIP_LEAD_SECONDS)
            decoded_path = run_root / "decoded" / f"{recording_id}.wav"
            clip_input = decoded_path if decoded_path.is_file() else recording_path
            event["recording_seconds"] = recording_seconds
            event["audio_event_source"] = (
                "gps"
                if event.get("goal_source") == "gps_bez_transkrypcji"
                else "transkrypcja"
            )
            event["audio_clip_start_seconds"] = start
            event["audio_clip_duration_seconds"] = CLIP_DURATION_SECONDS
            command = [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-ss",
                f"{start:.3f}",
                "-i",
                str(clip_input),
                "-t",
                str(int(CLIP_DURATION_SECONDS)),
                "-af",
                f"apad=pad_dur={int(CLIP_DURATION_SECONDS)}",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-c:a",
                "libmp3lame",
                "-b:a",
                "128k",
                str(clip_path),
            ]
            subprocess.run(command, cwd=PROJECT_ROOT, check=True)
            event["audio_to_verify"] = str(clip_path)


def markdown_cell(value: Any, fallback: str = "—") -> str:
    if value is None or value == "":
        return fallback
    return str(value).replace("|", "\\|").replace("\n", " ")


def render_report(report: dict[str, Any]) -> str:
    lines = [
        f"# Raport meczowy — {markdown_cell(report.get('session_date'))}",
        "",
        "Raport został przygotowany na podstawie pełnej transkrypcji large-v3, "
        "listy zawodników z bazy oraz danych GPS Suunto.",
        "",
    ]
    for match in report.get("matches", []):
        number = match.get("match_number", "?")
        lines.extend(
            [
                f"## Mecz #{number}",
                "",
                f"- Godzina rozpoczęcia: {markdown_cell(match.get('start_datetime'))}",
                f"- Godzina zakończenia: {markdown_cell(match.get('end_datetime'))}",
                "",
                "### Teamy",
                "",
            ]
        )
        teams = match.get("teams", [])
        if not teams:
            lines.append("Brak ustalonych teamów.")
        for team in teams:
            team_name = markdown_cell(team.get("name"), "nieustalony")
            lines.extend(
                [
                    f"#### {team_name}",
                    "",
                    f"- Kapitan: {markdown_cell(team.get('captain'))}",
                    f"- Bramkarz: {markdown_cell(team.get('goalkeeper'))}",
                    "- Składy:",
                ]
            )
            roster = team.get("players", [])
            lines.extend(f"  - {markdown_cell(player)}" for player in roster)
            if not roster:
                lines.append("  - —")
            lines.append("")
        lines.extend(
            [
                "### Eventy",
                "",
                "| Klasyfikacja gola | LP | Czas rzeczywisty | Minuta meczu | Event type | Strzelec | Asystent | Pewność | Dodatkowe info | Audio do potwierdzenia |",
                "| --- | ---: | --- | ---: | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for index, event in enumerate(match.get("events", []), start=1):
            audio = event.get("audio_to_verify")
            audio_label = f"![odsłuchaj]({audio})" if audio else "—"
            goal_source = (
                GOAL_SOURCE_LABELS.get(event.get("goal_source"), markdown_cell(event.get("goal_source")))
                if is_goal_event(event)
                else "—"
            )
            lines.append(
                "| "
                + " | ".join(
                    [
                        goal_source,
                        str(index),
                        markdown_cell(event.get("real_time")),
                        markdown_cell(event.get("match_minute")),
                        markdown_cell(event.get("event_type")),
                        markdown_cell(event.get("scorer")),
                        markdown_cell(event.get("assistant")),
                        markdown_cell(event.get("confidence")),
                        markdown_cell(event.get("notes")),
                        audio_label,
                    ]
                )
                + " |"
            )
        if not match.get("events"):
            lines.append("| — | — | — | — | — | — | — | — | Brak eventów | — |")
        lines.append("")
    manual_review = report.get("manual_review", [])
    lines.extend(["## Do ręcznej weryfikacji", ""])
    if manual_review:
        lines.extend(f"- {item}" for item in manual_review)
    else:
        lines.append("Brak dodatkowych pozycji.")
    return "\n".join(lines).rstrip() + "\n"


def write_manifest(
    run_root: Path,
    target_date: date,
    recordings: list[dict[str, Any]],
    gps_files: list[dict[str, Any]],
    players: list[dict[str, Any]],
) -> None:
    manifest = {
        "date": target_date.isoformat(),
        "run_root": str(run_root),
        "recordings": recordings,
        "gps_files": gps_files,
        "players_count": len(players),
        "isolation": "tmp/match_transcription_workflow; independent from tmp/match_audio",
    }
    (run_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    arguments = parse_arguments()
    source = arguments.source.expanduser().resolve()
    output_root = arguments.output_root.expanduser().resolve()
    if not source.is_dir():
        return fail(f"nie znaleziono katalogu źródłowego: {source}")
    if arguments.threads < 1:
        return fail("--threads musi być większe od zera")
    try:
        timezone = ZoneInfo(arguments.timezone)
        target_date = date.fromisoformat(arguments.date) if arguments.date else datetime.now(timezone).date()
    except ZoneInfoNotFoundError:
        return fail(f"nieznana strefa czasowa: {arguments.timezone}")
    except ValueError:
        return fail("--date musi mieć format YYYY-MM-DD")

    run_root = output_root / target_date.isoformat()
    try:
        recordings, gps_files = collect_inputs(
            source,
            run_root,
            target_date,
            timezone,
            force=arguments.force,
        )
        players = fetch_players_from_database(arguments.players_file)
        (run_root / "players.json").parent.mkdir(parents=True, exist_ok=True)
        (run_root / "players.json").write_text(
            json.dumps({"players": players}, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        for recording in recordings:
            if arguments.skip_transcription:
                paths = transcript_paths(run_root, recording)
                if not paths["json"].is_file():
                    raise FileNotFoundError(f"brak transcriptu: {paths['json']}")
                recording["transcript"] = {key: str(path) for key, path in paths.items()}
            else:
                transcribe_recording(
                    recording,
                    run_root,
                    model=arguments.model.expanduser().resolve(),
                    whisper_cli=arguments.whisper_cli.expanduser().resolve(),
                    vad_model=arguments.vad_model.expanduser().resolve(),
                    threads=arguments.threads,
                    cpu=arguments.cpu,
                    force=arguments.force,
                )
        write_manifest(run_root, target_date, recordings, gps_files, players)
        prompt = build_analysis_prompt(run_root, recordings, gps_files, players)
        prompt_path = run_root / "analysis_prompt.md"
        prompt_path.write_text(prompt, encoding="utf-8")
        if arguments.skip_analysis_thread and arguments.analysis_result:
            return fail("--skip-analysis-thread i --analysis-result nie mogą być użyte razem")
        if arguments.skip_analysis_thread:
            log(f"Prompt zapisany: {prompt_path}")
            return 0

        ai_output = (
            arguments.analysis_result.expanduser().resolve()
            if arguments.analysis_result
            else spawn_analysis_thread(run_root, prompt_path)
        )
        if not ai_output.is_file():
            raise FileNotFoundError(f"nie znaleziono wyniku analizy: {ai_output}")
        raw_report = extract_json(ai_output.read_text(encoding="utf-8"))
        raw_report["session_date"] = raw_report.get("session_date", target_date.isoformat())
        raw_report["recordings"] = recordings
        raw_report["gps"] = gps_summary(gps_files)
        raw_report["players_file"] = str(run_root / "players.json")
        create_audio_review_clips(raw_report, run_root)
        analysis_root = run_root / "analysis"
        (analysis_root / "ai_analysis.json").write_text(
            json.dumps(raw_report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        (analysis_root / "report.json").write_text(
            json.dumps(raw_report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        (analysis_root / "report.md").write_text(
            render_report(raw_report),
            encoding="utf-8",
        )
        log(f"Raport: {analysis_root / 'report.md'}")
        log(f"Dane: {analysis_root / 'report.json'}")
        return 0
    except (FileExistsError, FileNotFoundError, OSError, RuntimeError, ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        return fail(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
