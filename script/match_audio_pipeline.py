#!/usr/bin/env python3
"""Run the local development pipeline for paired match recordings."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import difflib
import json
import re
import shutil
import subprocess
import sys
import time
import unicodedata
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from collect_match_audio import DEFAULT_OUTPUT_ROOT, DEFAULT_SOURCE, collect
from extract_match_events import extract, same_scorer, segment_time


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CLEANER = PROJECT_ROOT / "script/clean_audio.py"
TRANSCRIBER = PROJECT_ROOT / "script/transcribe_audio.py"
DEFAULT_TRANSCRIPTION_MODEL = (
    PROJECT_ROOT / ".local/whisper.cpp/models/ggml-large-v3.bin"
)
# Zachowaj nazwę dla kompatybilności z istniejącymi odwołaniami, ale domyślnie
# nie używaj już modelu turbo/Q8.
DEFAULT_BATCH_MODEL = DEFAULT_TRANSCRIPTION_MODEL
DEFAULT_VERIFICATION_MODEL = DEFAULT_TRANSCRIPTION_MODEL
DEFAULT_PREPARE_WORKERS = 2
DEVICE_EVENT_TYPES = {
    1: "MATCH_START",
    2: "GOAL_MY",
    3: "GOAL_THEM",
    4: "UNDO_GOAL",
    5: "MATCH_END",
}
DEVICE_LOG_START_TOLERANCE_SECONDS = 300.0
DEVICE_LOG_GOAL_MATCH_TOLERANCE_SECONDS = 45.0
DEVICE_LOG_GOAL_SEARCH_BEFORE_SECONDS = 15.0
DEVICE_LOG_GOAL_SEARCH_AFTER_SECONDS = 45.0

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
MECZYK_FILENAME_RE = re.compile(
    r"^meczyk-(?P<day>\d{1,2})\s+(?P<month>[\wąćęłńóśźż]+)\s+"
    r"(?P<year>\d{4})\s+o\s+(?P<hour>\d{1,2}):(?P<minute>\d{2})$",
    re.IGNORECASE,
)
ROSTER_ANCHOR_RE = re.compile(
    r"(?:rafał|rafal).*?milik.*?(?:damian|drugi\s+team|drugim\s+teamie)",
    re.IGNORECASE | re.DOTALL,
)
FIVE_GOAL_RULE_RE = re.compile(
    r"(?:do|pierwszy\s+do)\s+(?:pięciu|pieciu|5)\s+"
    r"(?:bramek|goli|gole|prawek)(?:[^.\n]{0,50})?"
    r"(?:przerw|koniec|kończ|koncz)|"
    r"(?:do|pierwszy\s+do)\s+(?:pięciu|pieciu|5)\s+"
    r"(?:bramek|goli|gole|prawek)",
    re.IGNORECASE,
)
RECORDER_OPERATOR = {
    "name": "Wicu",
    "confidence": "high",
    "source": "informacja użytkownika",
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Kopiuje dzisiejsze nagrania, paruje Meczyk/R, wykonuje A/B, "
            "transkrybuje i wyciąga zdarzenia."
        ),
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--date", help="data YYYY-MM-DD (domyślnie: dzisiaj)")
    parser.add_argument("--timezone", default="Europe/Warsaw")
    parser.add_argument(
        "--stage",
        choices=("collect", "prepare", "transcribe", "analyze", "all"),
        default="all",
    )
    parser.add_argument("--meczyk-profile", default="bluetooth")
    parser.add_argument("--recorder-profile", default="recorder")
    parser.add_argument(
        "--prepare-workers",
        type=int,
        default=DEFAULT_PREPARE_WORKERS,
        help="liczba równoległych nagrań przygotowywanych przez FFmpeg",
    )
    parser.add_argument(
        "--max-pair-duration-difference",
        type=float,
        default=360,
        help="maksymalna różnica długości pary w sekundach",
    )
    parser.add_argument(
        "--sample-seconds",
        type=int,
        help="transkrybuj tylko tyle sekund do szybkiego testu",
    )
    parser.add_argument("--cpu", action="store_true")
    parser.add_argument(
        "--model",
        type=Path,
        default=DEFAULT_TRANSCRIPTION_MODEL,
        help="pełny model whisper.cpp large-v3 dla wszystkich transkrypcji",
    )
    parser.add_argument(
        "--verification-model",
        type=Path,
        default=DEFAULT_VERIFICATION_MODEL,
        help="pełny model large-v3 do krótkiej weryfikacji fragmentów",
    )
    parser.add_argument(
        "--no-score-verification",
        action="store_true",
        help="pomiń drugi przebieg large-v3 wokół końca meczu",
    )
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"Błąd: {message}", file=sys.stderr)
    return 2


def slugify(value: str) -> str:
    ascii_value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", ascii_value.casefold()).strip("-")


def annotate_recording_operators(recordings: list[dict[str, Any]]) -> None:
    for recording in recordings:
        if recording.get("source_type") == "recorder":
            recording["recorded_by"] = dict(RECORDER_OPERATOR)


def recording_operator_context(
    recordings: list[dict[str, Any]],
) -> dict[str, Any] | None:
    if any(recording.get("source_type") == "recorder" for recording in recordings):
        return dict(RECORDER_OPERATOR)
    return None


def apply_recorder_identity_to_own_goals(
    recordings: list[dict[str, Any]],
    analyses: list[dict[str, Any]],
) -> None:
    recordings_by_id = {recording["id"]: recording for recording in recordings}
    for analysis in analyses:
        recording = recordings_by_id.get(analysis["id"])
        if not recording or recording.get("source_type") != "recorder":
            continue
        operator = recording.get("recorded_by", {}).get("name")
        if not operator:
            continue
        for variant in analysis.get("variants", {}).values():
            events = variant.get("events", {})
            for goal in events.get("goals", []):
                corrections = goal.get("own_goal_evidence", [])
                if not corrections or goal.get("type") == "own_goal":
                    continue
                previous_scorer = goal.get("scorer")
                if previous_scorer and not same_scorer(previous_scorer, operator):
                    goal["initial_scorer_call"] = previous_scorer
                goal["type"] = "own_goal"
                goal["goal_type"] = "own_goal"
                goal["own_goal_player"] = operator
                goal["scorer"] = operator
                goal["assist"] = None
                goal["assist_candidates"] = []
                goal["confidence"] = "medium"
                for evidence in corrections:
                    if evidence not in goal["evidence"]:
                        goal["evidence"].append(evidence)


def parse_meczyk_recording_start(
    name: str,
    timezone: ZoneInfo,
) -> datetime | None:
    """Parse a Meczyk filename into the local date/time of the recording."""

    match = MECZYK_FILENAME_RE.match(Path(name).stem)
    if not match:
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
    if value is None:
        return None
    return value.isoformat(timespec="milliseconds")


def recording_start_datetime(
    recording: dict[str, Any],
    target_date: date,
    timezone: ZoneInfo,
) -> datetime | None:
    existing = recording.get("recording_start_datetime")
    if existing:
        try:
            return datetime.fromisoformat(str(existing))
        except ValueError:
            pass

    if recording.get("source_type") != "meczyk":
        return None

    parsed = parse_meczyk_recording_start(recording.get("name", ""), timezone)
    if parsed is None or parsed.date() != target_date:
        return None
    recording["recording_start_datetime"] = iso_datetime(parsed)
    recording["recording_start_source"] = "filename"
    return parsed


def seconds_from_timestamp(value: str) -> float:
    hours, minutes, seconds = value.replace(",", ".").split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def timestamp_from_seconds(value: float) -> str:
    total_milliseconds = max(0, round(value * 1000))
    hours, remainder = divmod(total_milliseconds, 3_600_000)
    minutes, remainder = divmod(remainder, 60_000)
    seconds, milliseconds = divmod(remainder, 1_000)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{milliseconds:03d}"


def absolute_recording_time(
    recording: dict[str, Any],
    recording_seconds: float | None,
    target_date: date,
    timezone: ZoneInfo,
) -> datetime | None:
    if recording_seconds is None:
        return None
    start = recording_start_datetime(recording, target_date, timezone)
    if start is None:
        return None
    return start + timedelta(seconds=recording_seconds)


def time_finding(
    recording: dict[str, Any],
    *,
    recording_seconds: float | None,
    target_date: date,
    timezone: ZoneInfo,
    status: str,
    source: str,
    evidence: dict[str, Any] | None,
) -> dict[str, Any]:
    absolute = absolute_recording_time(
        recording,
        recording_seconds,
        target_date,
        timezone,
    )
    return {
        "datetime": iso_datetime(absolute),
        "time": absolute.strftime("%H:%M:%S") if absolute else None,
        "recording_seconds": (
            round(float(recording_seconds), 3)
            if recording_seconds is not None
            else None
        ),
        "status": status,
        "source": source,
        "confidence": {
            "confirmed_audio": "high",
            "estimated_recording_boundary": "medium",
        }.get(status, "not_established"),
        "evidence": evidence,
    }


def parse_device_timestamp(value: Any, timezone: ZoneInfo) -> datetime:
    text = str(value).strip()
    if text.endswith("Z"):
        text = f"{text[:-1]}+00:00"
    parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone)
    return parsed.astimezone(timezone)


def same_channel(left: Any, right: Any) -> bool:
    return str(left) == str(right)


def deduplicate_device_samples(samples: list[dict[str, Any]]) -> list[dict[str, Any]]:
    deduplicated: list[dict[str, Any]] = []
    previous_value: Any = object()
    for sample in sorted(samples, key=lambda item: item["timestamp"]):
        if sample["value"] == previous_value:
            continue
        deduplicated.append(sample)
        previous_value = sample["value"]
    return deduplicated


def parse_device_log_document(
    document: dict[str, Any],
    target_date: date,
    timezone: ZoneInfo,
) -> dict[str, Any]:
    device_log = document.get("DeviceLog")
    if not isinstance(device_log, dict):
        raise ValueError("brak obiektu DeviceLog")

    zapps = device_log.get("Zapps", [])
    app = next(
        (
            item
            for item in zapps
            if isinstance(item, dict)
            and item.get("Id") == "footba01"
            and item.get("Name") == "Football Match"
        ),
        None,
    )
    if app is None:
        raise ValueError("brak aplikacji Football Match (footba01)")

    channels = app.get("Channels", [])
    channel = next(
        (
            item
            for item in channels
            if isinstance(item, dict) and item.get("VariableId") == "event_code"
        ),
        None,
    )
    if channel is None or "ChannelId" not in channel:
        raise ValueError("brak kanału event_code")
    channel_id = channel["ChannelId"]

    samples: list[dict[str, Any]] = []
    for sample in device_log.get("Samples", []):
        if not isinstance(sample, dict):
            continue
        zapp_sample = sample.get("ZappSample")
        if not isinstance(zapp_sample, dict) or not same_channel(
            zapp_sample.get("ChannelId"),
            channel_id,
        ):
            continue
        try:
            value = int(float(zapp_sample["Value"]))
            timestamp = parse_device_timestamp(sample["TimeISO8601"], timezone)
        except (KeyError, TypeError, ValueError, OverflowError):
            continue
        if timestamp.date() != target_date:
            continue
        samples.append(
            {
                "value": value,
                "timestamp": iso_datetime(timestamp),
            }
        )

    deduplicated = deduplicate_device_samples(samples)
    events: list[dict[str, Any]] = []
    ignored_samples: list[dict[str, Any]] = []
    for sample in deduplicated:
        event_type = sample["value"] // 10
        event_name = DEVICE_EVENT_TYPES.get(event_type)
        if event_name is None:
            ignored_samples.append(
                {
                    **sample,
                    "reason": "unknown_event_type",
                }
            )
            continue
        events.append(
            {
                **sample,
                "event_type": event_name,
            }
        )

    replay = replay_device_events(events)
    return {
        "application": {
            "id": app.get("Id"),
            "name": app.get("Name"),
        },
        "channel_id": channel_id,
        "raw_sample_count": len(samples),
        "sample_count": len(deduplicated),
        "event_count": len(events),
        "ignored_sample_count": len(ignored_samples),
        "ignored_samples": ignored_samples,
        "events": events,
        "matches": replay["matches"],
        "ignored_events": replay["ignored_events"],
    }


def replay_device_events(events: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    matches: list[dict[str, Any]] = []
    ignored_events: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None

    def finish_match(match: dict[str, Any]) -> None:
        match["final_score"] = dict(match["score"])
        match["goal_count"] = sum(
            1 for goal in match["goals"] if goal.get("active")
        )

    for event in events:
        event_copy = dict(event)
        event_type = event_copy.get("event_type")
        if event_type == "MATCH_START":
            if current is not None:
                current["status"] = "interrupted_by_match_start"
                current["end_reason"] = "next_match_start"
                finish_match(current)
                matches.append(current)
            current = {
                "match_number": len(matches) + 1,
                "status": "active",
                "start": event_copy,
                "end": None,
                "events": [event_copy],
                "goals": [],
                "undo_events": [],
                "unmatched_undo_events": [],
                "score": {"my": 0, "them": 0},
            }
            continue

        if current is None:
            ignored_events.append(
                {
                    **event_copy,
                    "reason": "outside_match",
                }
            )
            continue

        current["events"].append(event_copy)
        if event_type in {"GOAL_MY", "GOAL_THEM"}:
            side = "my" if event_type == "GOAL_MY" else "them"
            current["score"][side] += 1
            current["goals"].append(
                {
                    "goal_number": len(current["goals"]) + 1,
                    "side": side,
                    "active": True,
                    "timestamp": event_copy["timestamp"],
                    "value": event_copy["value"],
                    "event_type": event_type,
                    "score_after": dict(current["score"]),
                }
            )
        elif event_type == "UNDO_GOAL":
            active_goals = [
                goal for goal in reversed(current["goals"]) if goal["active"]
            ]
            if active_goals:
                goal = active_goals[0]
                goal["active"] = False
                goal["undone_by"] = event_copy
                current["score"][goal["side"]] -= 1
                event_copy["undoes_goal_number"] = goal["goal_number"]
                current["undo_events"].append(event_copy)
            else:
                current["unmatched_undo_events"].append(event_copy)
        elif event_type == "MATCH_END":
            current["end"] = event_copy
            current["status"] = "completed"
            finish_match(current)
            matches.append(current)
            current = None

    if current is not None:
        current["end_reason"] = "end_of_device_log"
        finish_match(current)
        matches.append(current)

    return {
        "matches": matches,
        "ignored_events": ignored_events,
    }


def load_device_logs(
    manifest: dict[str, Any],
    target_date: date,
    timezone: ZoneInfo,
) -> dict[str, Any]:
    records = [
        record
        for record in manifest.get("files", [])
        if record.get("kind") == "device_log"
    ]
    if not records:
        return {
            "status": "not_found",
            "files": [],
            "events": [],
            "matches": [],
            "errors": [],
        }

    file_results: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    for record in records:
        path = Path(str(record["destination"]))
        try:
            document = json.loads(path.read_text(encoding="utf-8"))
            parsed = parse_device_log_document(document, target_date, timezone)
        except (OSError, json.JSONDecodeError, ValueError) as error:
            error_details = {
                "path": str(path),
                "error": str(error),
            }
            errors.append(error_details)
            file_results.append({**record, "status": "error", "error": str(error)})
            continue

        events.extend(parsed["events"])
        file_results.append(
            {
                **record,
                "status": "parsed",
                "channel_id": parsed["channel_id"],
                "raw_sample_count": parsed["raw_sample_count"],
                "sample_count": parsed["sample_count"],
                "event_count": parsed["event_count"],
            }
        )

    events = deduplicate_device_samples(events)
    replay = replay_device_events(events)
    status = "parsed" if events else "empty"
    if errors and not events:
        status = "error"
    return {
        "status": status,
        "files": file_results,
        "events": events,
        "event_count": len(events),
        "matches": replay["matches"],
        "ignored_events": replay["ignored_events"],
        "errors": errors,
    }


def probe_audio(path: Path) -> dict[str, Any]:
    command = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "a:0",
        "-show_entries",
        "format=duration,size:stream=codec_name,sample_rate,channels,bit_rate",
        "-of",
        "json",
        str(path),
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    document = json.loads(result.stdout)
    stream = document["streams"][0]
    audio_format = document["format"]
    return {
        "duration": round(float(audio_format["duration"]), 3),
        "size": int(audio_format["size"]),
        "codec": stream.get("codec_name"),
        "sample_rate": int(stream.get("sample_rate", 0)),
        "channels": int(stream.get("channels", 0)),
        "bit_rate": int(stream.get("bit_rate", 0) or 0),
    }


def pair_recordings(
    recordings: list[dict[str, Any]],
    max_difference: float,
) -> tuple[list[dict[str, Any]], list[str]]:
    meczyk = [item for item in recordings if item["source_type"] == "meczyk"]
    recorder = [item for item in recordings if item["source_type"] == "recorder"]
    candidates = sorted(
        (
            abs(left["audio"]["duration"] - right["audio"]["duration"]),
            left,
            right,
        )
        for left in meczyk
        for right in recorder
    )
    used_meczyk: set[str] = set()
    used_recorder: set[str] = set()
    pairs: list[dict[str, Any]] = []

    for difference, left, right in candidates:
        if difference > max_difference:
            continue
        if left["id"] in used_meczyk or right["id"] in used_recorder:
            continue
        used_meczyk.add(left["id"])
        used_recorder.add(right["id"])
        pairs.append(
            {
                "id": "",
                "meczyk": left["id"],
                "recorder": right["id"],
                "duration_difference": round(difference, 3),
            }
        )

    pairs.sort(key=lambda pair: pair["meczyk"])
    for index, pair in enumerate(pairs, start=1):
        pair["id"] = f"pair-{index:02d}"
    matched = used_meczyk | used_recorder
    unmatched = [item["id"] for item in recordings if item["id"] not in matched]
    return pairs, unmatched


def run_logged(command: list[str], log_path: Path) -> bool:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Uruchamiam: {' '.join(command[:3])} …")
    with log_path.open("a", encoding="utf-8") as log:
        log.write("\n$ " + " ".join(command) + "\n")
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    return result.returncode == 0


def prepare_recording(
    recording: dict[str, Any],
    run_root: Path,
    profile: str,
    *,
    force: bool,
) -> None:
    source = Path(recording["path"])
    directory = run_root / "prepared" / recording["id"]
    neutral = directory / "neutral.wav"
    cleaned = directory / "clean.wav"
    log_path = run_root / "logs" / f"{recording['id']}-prepare.log"

    for destination, selected_profile in ((neutral, "neutral"), (cleaned, profile)):
        if destination.is_file() and not force:
            continue
        command = [
            "python3",
            str(CLEANER),
            str(source),
            "--output",
            str(destination),
            "--profile",
            selected_profile,
        ]
        if force:
            command.append("--force")
        if not run_logged(command, log_path):
            raise RuntimeError(f"cleaning nie powiódł się dla {recording['id']}")

    recording["profile"] = profile
    recording["neutral_path"] = str(neutral)
    recording["clean_path"] = str(cleaned)


def prepare_recordings(
    recordings: list[dict[str, Any]],
    run_root: Path,
    profiles: dict[str, str],
    *,
    force: bool,
    workers: int,
) -> None:
    tasks = [(recording, profiles[recording["id"]]) for recording in recordings]
    if workers == 1:
        for recording, profile in tasks:
            prepare_recording(recording, run_root, profile, force=force)
        return

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [
            executor.submit(
                prepare_recording,
                recording,
                run_root,
                profile,
                force=force,
            )
            for recording, profile in tasks
        ]
        for future in futures:
            future.result()


def model_marker_path(json_output: Path) -> Path:
    return Path(f"{json_output}.model.json")


def transcript_matches_model(json_output: Path, model: Path) -> bool:
    marker = model_marker_path(json_output)
    if not marker.is_file():
        return False
    try:
        metadata = json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return Path(metadata.get("model_path", "")).resolve() == model.resolve()


def write_model_marker(json_output: Path, model: Path) -> None:
    model_marker_path(json_output).write_text(
        json.dumps(
            {
                "model_name": model.name,
                "model_path": str(model.resolve()),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def write_transcription_timing(
    run_root: Path,
    recording: dict[str, Any],
    variant: str,
    model: Path,
    elapsed_seconds: float,
    device: str,
) -> None:
    path = run_root / "transcription_timings.json"
    if path.is_file():
        timings = json.loads(path.read_text(encoding="utf-8"))
    else:
        timings = []
    entry = {
        "recording_id": recording["id"],
        "recording_name": recording["name"],
        "variant": variant,
        "model_name": model.name,
        "device": device,
        "elapsed_seconds": round(elapsed_seconds, 2),
    }
    timings = [
        item
        for item in timings
        if (item["recording_id"], item["variant"])
        != (entry["recording_id"], entry["variant"])
    ]
    timings.append(entry)
    timings.sort(key=lambda item: (item["recording_id"], item["variant"]))
    path.write_text(
        json.dumps(timings, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def transcribe_variant(
    recording: dict[str, Any],
    run_root: Path,
    variant: str,
    *,
    sample_seconds: int | None,
    cpu: bool,
    force: bool,
    model: Path,
) -> None:
    started_at = time.perf_counter()
    source = Path(recording[f"{variant}_path"])
    output = run_root / "transcripts" / recording["id"] / variant
    json_output = Path(f"{output}.json")
    log_path = run_root / "logs" / f"{recording['id']}-{variant}-transcribe.log"
    if (
        json_output.is_file()
        and not force
        and transcript_matches_model(json_output, model)
    ):
        recording[f"{variant}_transcript"] = str(output)
        return

    command = [
        "python3",
        str(TRANSCRIBER),
        str(source),
        "--output",
        str(output),
        "--model",
        str(model),
    ]
    if sample_seconds:
        command.extend(["--duration", str(sample_seconds)])
    if cpu:
        command.append("--cpu")
    if force:
        command.append("--force")

    device = "cpu" if cpu else "metal"
    succeeded = run_logged(command, log_path)
    if not succeeded and not cpu:
        print(f"Metal nie powiódł się dla {recording['id']} ({variant}); ponawiam na CPU.")
        device = "cpu"
        retry_command = [*command, "--cpu"]
        if "--force" not in retry_command:
            retry_command.append("--force")
        succeeded = run_logged(retry_command, log_path)
    if not succeeded:
        raise RuntimeError(f"transkrypcja nie powiodła się dla {recording['id']} ({variant})")
    write_model_marker(json_output, model)
    write_transcription_timing(
        run_root,
        recording,
        variant,
        model,
        time.perf_counter() - started_at,
        device,
    )
    recording[f"{variant}_transcript"] = str(output)


def attach_existing_transcript_paths(
    recordings: list[dict[str, Any]],
    run_root: Path,
) -> None:
    """Restore transcript paths when analyze resumes from an older pipeline state."""

    for recording in recordings:
        for variant in ("neutral", "clean"):
            output = run_root / "transcripts" / recording["id"] / variant
            if Path(f"{output}.json").is_file():
                recording[f"{variant}_transcript"] = str(output)


def transcript_metrics(document: dict[str, Any]) -> dict[str, Any]:
    segments = document.get("transcription", [])
    text = " ".join(str(segment.get("text", "")) for segment in segments)
    words = re.findall(r"\w+", text.casefold(), flags=re.UNICODE)
    return {"segments": len(segments), "words": len(words), "text": text, "word_list": words}


def analyze_recording(recording: dict[str, Any], run_root: Path) -> dict[str, Any]:
    variants: dict[str, Any] = {}
    for variant in ("neutral", "clean"):
        base = Path(recording[f"{variant}_transcript"])
        document = json.loads(Path(f"{base}.json").read_text(encoding="utf-8"))
        metrics = transcript_metrics(document)
        events = extract(document, f"{recording['id']}:{variant}")
        event_path = run_root / "analysis/events" / f"{recording['id']}-{variant}.json"
        event_path.parent.mkdir(parents=True, exist_ok=True)
        event_path.write_text(
            json.dumps(events, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        variants[variant] = {
            "segments": metrics["segments"],
            "words": metrics["words"],
            "goals": len(events["goals"]),
            "scores": len(events["scores"]),
            "events_path": str(event_path),
            "events": events,
            "_text": metrics["text"],
            "_words": metrics["word_list"],
        }

    neutral = variants["neutral"]
    clean = variants["clean"]
    similarity = difflib.SequenceMatcher(None, neutral["_words"], clean["_words"]).ratio()
    if clean["goals"] > neutral["goals"]:
        recommendation = "clean"
        recommendation_reason = "more_detected_goals"
    elif clean["goals"] < neutral["goals"]:
        recommendation = "neutral"
        recommendation_reason = "more_detected_goals"
    elif clean["scores"] > neutral["scores"]:
        recommendation = "clean"
        recommendation_reason = "more_detected_scores"
    elif clean["scores"] < neutral["scores"]:
        recommendation = "neutral"
        recommendation_reason = "more_detected_scores"
    else:
        recommendation = "neutral"
        recommendation_reason = "no_audio_based_advantage"

    for details in variants.values():
        details.pop("_text")
        details.pop("_words")
    return {
        "id": recording["id"],
        "source_type": recording["source_type"],
        "profile": recording["profile"],
        "similarity": round(similarity, 4),
        "comparison": {
            "segment_delta_clean_minus_neutral": clean["segments"] - neutral["segments"],
            "word_delta_clean_minus_neutral": clean["words"] - neutral["words"],
            "goal_delta_clean_minus_neutral": clean["goals"] - neutral["goals"],
            "score_delta_clean_minus_neutral": clean["scores"] - neutral["scores"],
            "word_count_is_not_quality_evidence": True,
        },
        "recommended_variant": recommendation,
        "recommendation_reason": recommendation_reason,
        "variants": variants,
    }


def pair_variant_text_similarities(
    pair: dict[str, Any],
    recordings_by_id: dict[str, dict[str, Any]],
) -> dict[str, float]:
    word_lists: dict[tuple[str, str], list[str]] = {}
    for source_name, identifier in (
        ("meczyk", pair["meczyk"]),
        ("recorder", pair["recorder"]),
    ):
        for variant in ("neutral", "clean"):
            base = Path(recordings_by_id[identifier][f"{variant}_transcript"])
            document = json.loads(Path(f"{base}.json").read_text(encoding="utf-8"))
            word_lists[(source_name, variant)] = transcript_metrics(document)["word_list"]

    return {
        f"{left_variant}:{right_variant}": round(
            difflib.SequenceMatcher(
                None,
                word_lists[("meczyk", left_variant)],
                word_lists[("recorder", right_variant)],
            ).ratio(),
            4,
        )
        for left_variant in ("neutral", "clean")
        for right_variant in ("neutral", "clean")
    }


def goal_signature(
    events: dict[str, Any],
) -> list[tuple[str | None, str | None, str | None]]:
    return [
        (
            goal.get("type", "goal"),
            goal.get("scorer"),
            goal.get("assist"),
        )
        for goal in events["goals"]
    ]


def event_similarity(left: dict[str, Any], right: dict[str, Any]) -> float:
    left_signature = goal_signature(left)
    right_signature = goal_signature(right)
    if not left_signature or not right_signature:
        return 0.0
    return difflib.SequenceMatcher(None, left_signature, right_signature).ratio()


def verify_pair_and_select_variants(
    pair: dict[str, Any],
    analyses_by_id: dict[str, dict[str, Any]],
) -> None:
    text_similarity = max(pair["variant_text_similarities"].values())
    pair["text_similarity"] = text_similarity
    if text_similarity >= 0.25:
        pair["verification"] = "confirmed"
    elif text_similarity >= 0.10:
        pair["verification"] = "review"
    else:
        pair["verification"] = "low_quality"

    left = analyses_by_id[pair["meczyk"]]
    right = analyses_by_id[pair["recorder"]]
    candidates: list[tuple[tuple[float, float, int], str, str]] = []
    for left_variant in ("neutral", "clean"):
        for right_variant in ("neutral", "clean"):
            left_details = left["variants"][left_variant]
            right_details = right["variants"][right_variant]
            similarity = event_similarity(left_details["events"], right_details["events"])
            variant_text_similarity = pair["variant_text_similarities"][
                f"{left_variant}:{right_variant}"
            ]
            original_recommendations = int(left["recommended_variant"] == left_variant)
            original_recommendations += int(right["recommended_variant"] == right_variant)
            candidates.append(
                (
                    (similarity, variant_text_similarity, original_recommendations),
                    left_variant,
                    right_variant,
                )
            )

    score, left_variant, right_variant = max(candidates, key=lambda item: item[0])
    pair["event_similarity"] = round(score[0], 4)
    pair["selected_text_similarity"] = score[1]
    pair["selected_variants"] = {
        "meczyk": left_variant,
        "recorder": right_variant,
    }
    if pair["verification"] == "confirmed" and score[0] >= 0.8:
        left["recommended_variant"] = left_variant
        right["recommended_variant"] = right_variant
        left["recommendation_reason"] = "paired_event_confirmation"
        right["recommendation_reason"] = "paired_event_confirmation"


def final_score_candidate(events: dict[str, Any]) -> str | None:
    goals = events["goals"]
    if not goals:
        return None
    goal_count = len(goals)
    last_goal_time = goals[-1]["recording_seconds"]
    candidates = [
        score
        for score in events["scores"]
        if score["home"] + score["away"] == goal_count
        and score["recording_seconds"] >= last_goal_time - 30
    ]
    if not candidates:
        return None
    score = candidates[-1]
    return f"{score['home']}:{score['away']}"


def final_score_evidence(
    events: dict[str, Any],
    goal_count: int,
) -> dict[str, Any] | None:
    if not events["goals"]:
        return None

    last_goal_time = events["goals"][-1]["recording_seconds"]
    candidates = [
        score
        for score in events["scores"]
        if score["home"] + score["away"] == goal_count
        and score["recording_seconds"] >= last_goal_time - 30
    ]
    if not candidates:
        return None
    candidate = candidates[-1]
    return {
        "value": f"{candidate['home']}:{candidate['away']}",
        "evidence": candidate["evidence"],
        "recording_seconds": candidate["recording_seconds"],
    }


def goal_matches(left: dict[str, Any], right: dict[str, Any]) -> bool:
    if left.get("type", "goal") != right.get("type", "goal"):
        return False
    if not same_scorer(left.get("scorer"), right.get("scorer")):
        return False
    left_assist = left.get("assist")
    right_assist = right.get("assist")
    if left_assist is None or right_assist is None:
        return left_assist is None and right_assist is None
    return same_scorer(left_assist, right_assist)


def goal_is_auto_counted(goal: dict[str, Any]) -> bool:
    """Only count a goal after a local repeat or independent Meczyk/R match."""

    return bool(
        goal.get("goal_confirmation") == "repeated_within_5_seconds"
        or goal.get("confirmed_by_both_recordings") is True
    )


def confirmation_for_goal(
    goal: dict[str, Any],
    recorder_goals: list[dict[str, Any]],
    used_recorder_indexes: set[int],
    *,
    meczyk_id: str,
    recorder_id: str | None,
) -> None:
    corrected_own_goal = goal.get("type") == "own_goal"
    goal["evidence_by_source"] = {"meczyk": goal.get("evidence", [])}
    goal["confirmed_by_both_recordings"] = False
    goal["source"] = meczyk_id
    goal["source_confidence"] = (
        "single_source_corrected" if corrected_own_goal else "single_source"
    )
    goal["auto_counted"] = goal_is_auto_counted(goal)
    goal["automatic_count_reason"] = (
        "repeated_within_5_seconds"
        if goal["auto_counted"]
        else "single_or_spread_announcement"
    )
    goal["confidence"] = "medium"
    goal["scorer_source"] = {
        "source": meczyk_id,
        "confidence": "medium",
    }
    goal["assist_source"] = {
        "source": meczyk_id,
        "confidence": "medium" if goal.get("assist") else "not_recognized",
    }

    if not recorder_id:
        return

    matching_index = next(
        (
            index
            for index, recorder_goal in enumerate(recorder_goals)
            if index not in used_recorder_indexes
            and goal_matches(goal, recorder_goal)
        ),
        None,
    )
    if matching_index is None:
        return

    used_recorder_indexes.add(matching_index)
    recorder_goal = recorder_goals[matching_index]
    goal["evidence_by_source"]["recorder"] = recorder_goal.get("evidence", [])
    goal["own_goal_evidence_by_source"]["recorder"] = recorder_goal.get(
        "own_goal_evidence",
        [],
    )
    goal["confirmed_by_both_recordings"] = True
    goal["auto_counted"] = True
    goal["automatic_count_reason"] = "independent_meczyk_r_confirmation"
    goal["source"] = f"{meczyk_id} + {recorder_id}"
    goal["source_confidence"] = (
        "paired_with_correction" if corrected_own_goal else "paired"
    )
    goal["confidence"] = "medium" if corrected_own_goal else "high"
    goal["scorer_source"] = {
        "source": f"{meczyk_id} + {recorder_id}",
        "confidence": "medium" if corrected_own_goal else "high",
    }
    goal["assist_source"] = {
        "source": f"{meczyk_id} + {recorder_id}",
        "confidence": "high" if goal.get("assist") else "not_recognized",
    }


def annotate_goal_sources(
    goals: list[dict[str, Any]],
    recorder_goals: list[dict[str, Any]] | None,
    *,
    meczyk_id: str,
    recorder_id: str | None,
) -> list[dict[str, Any]]:
    used_recorder_indexes: set[int] = set()
    for goal in goals:
        goal["own_goal_evidence_by_source"] = {
            "meczyk": goal.get("own_goal_evidence", [])
        }
        confirmation_for_goal(
            goal,
            recorder_goals or [],
            used_recorder_indexes,
            meczyk_id=meczyk_id,
            recorder_id=recorder_id,
        )
        goal["minute_source"] = {
            "source": "start audio + timestamp transkrypcji Meczyk",
            "confidence": "high" if goal.get("match_minute") else "not_established",
        }
    return [
        dict(goal)
        for index, goal in enumerate(recorder_goals or [])
        if index not in used_recorder_indexes
    ]


def match_boundary(
    candidates: list[dict[str, Any]],
    *,
    after: float | None = None,
) -> dict[str, Any] | None:
    eligible = candidates
    if after is not None:
        eligible = [item for item in candidates if item["recording_seconds"] >= after]
    return eligible[0] if eligible else None


def normalized_search_text(value: str) -> str:
    return (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode()
        .casefold()
    )


def load_variant_document(recording: dict[str, Any], variant: str) -> dict[str, Any]:
    base = Path(recording[f"{variant}_transcript"])
    return json.loads(Path(f"{base}.json").read_text(encoding="utf-8"))


def context_segment_matches(text: str, purpose: str) -> bool:
    normalized = normalized_search_text(text)
    if purpose == "session_roster":
        return (
            ("rafal" in normalized or "rafa" in normalized)
            and "milik" in normalized
            and "damian" in normalized
        )
    if purpose == "five_goal_rule":
        return bool(FIVE_GOAL_RULE_RE.search(text)) or (
            "pieciu" in normalized
            and "przerw" in normalized
        )
    return False


def find_context_fragment(
    recordings: list[dict[str, Any]],
    analyses: list[dict[str, Any]],
    purpose: str,
    source_type: str | None = None,
) -> dict[str, Any] | None:
    analysis_by_id = {analysis["id"]: analysis for analysis in analyses}
    ordered = sorted(
        recordings,
        key=lambda recording: (
            recording["source_type"] != "meczyk",
            bool(
                analysis_by_id.get(recording["id"], {})
                .get("variants", {})
                .get("neutral", {})
                .get("events", {})
                .get("goals")
            )
            if purpose == "five_goal_rule"
            else False,
            recording["id"],
        ),
    )
    for recording in ordered:
        if source_type and recording["source_type"] != source_type:
            continue
        variants = ("neutral", "clean") if purpose == "five_goal_rule" else ("clean", "neutral")
        for variant in variants:
            transcript_base = recording.get(f"{variant}_transcript")
            if not transcript_base:
                continue
            document = load_variant_document(recording, variant)
            for segment in document.get("transcription", []):
                text = str(segment.get("text", "")).strip()
                if not text or not context_segment_matches(text, purpose):
                    continue
                start, finish = segment_time(segment)
                clip_start = max(start - (10 if purpose == "session_roster" else 6), 0)
                minimum_end = start + (35 if purpose == "session_roster" else 0)
                clip_end = min(
                    max(finish + 6, minimum_end),
                    recording["audio"]["duration"],
                )
                return {
                    "purpose": purpose,
                    "recording_id": recording["id"],
                    "variant": variant,
                    "input_path": recording[f"{variant}_path"],
                    "clip_start_seconds": round(clip_start, 3),
                    "clip_duration_seconds": round(max(clip_end - clip_start, 1), 3),
                    "batch_evidence": {
                        "from": segment["timestamps"]["from"],
                        "to": segment["timestamps"]["to"],
                        "text": text,
                    },
                }
    return None


def verify_context_fragment(
    fragment: dict[str, Any],
    run_root: Path,
    model: Path,
    *,
    force: bool,
) -> dict[str, Any]:
    directory = run_root / "verification" / "context" / fragment["purpose"]
    source_id = fragment["recording_id"]
    variant = fragment["variant"]
    clip = directory / f"{source_id}-{variant}-clip.wav"
    output = directory / f"{source_id}-{variant}-large-v3"
    transcript = Path(f"{output}.json")
    log_path = run_root / "logs" / f"{source_id}-{fragment['purpose']}-large-v3.log"
    directory.mkdir(parents=True, exist_ok=True)

    if force or not transcript.is_file():
        clip_command = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "warning",
            "-y",
            "-ss",
            f"{fragment['clip_start_seconds']:.3f}",
            "-t",
            f"{fragment['clip_duration_seconds']:.3f}",
            "-i",
            fragment["input_path"],
            "-c:a",
            "pcm_s16le",
            str(clip),
        ]
        if not run_logged(clip_command, log_path):
            raise RuntimeError(
                "nie udało się wyciąć fragmentu large-v3: "
                f"{source_id}/{fragment['purpose']}"
            )

        transcribe_command = [
            "python3",
            str(TRANSCRIBER),
            str(clip),
            "--output",
            str(output),
            "--model",
            str(model),
            "--cpu",
            "--force",
        ]
        if not run_logged(transcribe_command, log_path):
            raise RuntimeError(
                "nie udała się weryfikacja large-v3: "
                f"{source_id}/{fragment['purpose']}"
            )

    document = json.loads(transcript.read_text(encoding="utf-8"))
    evidence = []
    for segment in document.get("transcription", []):
        start, finish = segment_time(segment)
        evidence.append(
            {
                "from": timestamp_from_seconds(
                    fragment["clip_start_seconds"] + start
                ),
                "to": timestamp_from_seconds(
                    fragment["clip_start_seconds"] + finish
                ),
                "clip_from": segment["timestamps"]["from"],
                "clip_to": segment["timestamps"]["to"],
                "text": str(segment.get("text", "")).strip(),
            }
        )

    return {
        **fragment,
        "model": model.name,
        "clip_path": str(clip),
        "transcript_path": str(output),
        "evidence": evidence,
    }


def roster_member(
    name: str | None,
    *,
    raw: str,
    confidence: str,
    status: str = "resolved",
    alias: str | None = None,
    candidates: list[str] | None = None,
    role: str | None = None,
    source: str | None = None,
) -> dict[str, Any]:
    return {
        "name": name,
        "raw": raw,
        "status": status,
        "confidence": confidence,
        "alias": alias,
        "candidate_names": candidates or [],
        "role": role,
        "source": source,
    }


def build_session_context(
    recordings: list[dict[str, Any]],
    verification_fragments: list[dict[str, Any]],
) -> dict[str, Any]:
    roster_fragments = [
        fragment
        for fragment in verification_fragments
        if fragment["purpose"] == "session_roster"
    ]
    rule_fragments = [
        fragment
        for fragment in verification_fragments
        if fragment["purpose"] == "five_goal_rule"
    ]
    roster_texts = [
        " ".join(item["text"] for item in fragment["evidence"])
        for fragment in roster_fragments
    ]
    roster_text = " ".join(roster_texts)
    normalized_roster = normalized_search_text(roster_text)
    roster_verified = (
        len(roster_fragments) >= 2
        and ("rafal" in normalized_roster or "rafa" in normalized_roster)
        and "milik" in normalized_roster
        and "damian" in normalized_roster
    )

    roster_evidence = [
        {
            "recording_id": fragment["recording_id"],
            "variant": fragment["variant"],
            "model": fragment["model"],
            "evidence": fragment["evidence"],
        }
        for fragment in roster_fragments
    ]
    confidence = "high" if roster_verified else "low"
    rosters = [
        {
            "team": "team_1",
            "label": "Drużyna Wica",
            "confidence": confidence,
            "members": [
                roster_member(
                    "Rafał (Rafik)",
                    raw="Rafał",
                    alias="Rafik",
                    confidence="high",
                    source="informacja użytkownika: Rafał oznacza Rafała (Rafika)",
                ),
                roster_member(
                    "Marcin (Milik)",
                    raw="Milik",
                    alias="Milik",
                    confidence="high",
                    source="informacja użytkownika: Milik oznacza Marcina (Milika)",
                ),
                roster_member(
                    "Daniel",
                    raw="Daniel Żaba",
                    alias="Żaba",
                    confidence=confidence,
                ),
                roster_member(
                    "Mati",
                    raw="Mati Inter",
                    alias="Inter",
                    confidence=confidence,
                ),
                roster_member("Baca", raw="Baca", confidence=confidence),
                roster_member("Przemo", raw="Przemo", confidence=confidence),
                roster_member(
                    RECORDER_OPERATOR["name"],
                    raw="ja",
                    confidence="high",
                    alias="nagrywający",
                    source="informacja użytkownika: osoba nagrywająca to Wicu",
                ),
            ],
            "evidence": roster_evidence,
        },
        {
            "team": "team_2",
            "label": "Drużyna Piotrka (Cash)",
            "confidence": confidence,
            "members": [
                roster_member(
                    "Kamil",
                    raw="Kamil",
                    alias="Marcelo",
                    confidence="high",
                    source="informacja użytkownika: samo Kamil oznacza Marcelo",
                ),
                roster_member(
                    "Szymon (Koksu)",
                    raw="Szymon Nowy",
                    alias="Koksu",
                    confidence="high",
                    source="informacja użytkownika: Szymon Nowy oznacza Szymona (Koksu)",
                ),
                roster_member(
                    "Piotrek (Cash)",
                    raw="Mati/Cash",
                    alias="Cash",
                    confidence="high",
                    source="informacja użytkownika: Mati Cash oznacza Piotrka (Cash)",
                ),
                roster_member(
                    "Kamil (Barcelona)",
                    raw="Kamil Nowy",
                    alias="Barcelona",
                    confidence="high",
                    source="informacja użytkownika: Kamil Nowy oznacza Kamila (Barcelona)",
                ),
                roster_member("Płaczek", raw="Płaczek", confidence=confidence),
                roster_member(
                    "Adi",
                    raw="Adrian/Adi",
                    confidence="high",
                    source="informacja użytkownika: Adrian oznacza Adiego",
                ),
                roster_member("Dominik", raw="Dominik", confidence=confidence),
                roster_member(
                    "Damian",
                    raw="Damian",
                    confidence="high",
                    role="rotational",
                    source="informacja użytkownika: Damian gra w Drużynie Piotrka (Cash), ID 4",
                ),
            ],
            "evidence": roster_evidence,
        },
    ]
    if not roster_verified:
        rosters = [
            {
                "team": team,
                "label": label,
                "confidence": "low",
                "members": [
                    roster_member(
                        None,
                        raw="skład nierozpoznany",
                        confidence="low",
                        status="unresolved",
                    )
                ],
                "evidence": roster_evidence,
            }
            for team, label in (("team_1", "Drużyna Wica"), ("team_2", "Drużyna Piotrka (Cash)"))
        ]
    for roster in rosters:
        for member in roster["members"]:
            member["evidence"] = roster_evidence

    rule_evidence = [
        evidence
        for fragment in rule_fragments
        for evidence in fragment["evidence"]
        if FIVE_GOAL_RULE_RE.search(evidence["text"])
        or (
            "pieciu" in normalized_search_text(evidence["text"])
            and "przerw" in normalized_search_text(evidence["text"])
        )
    ]
    rule_status = "confirmed" if rule_evidence else "unconfirmed"
    return {
        "recording_operator": recording_operator_context(recordings),
        "rosters": rosters,
        "roster_verification": {
            "status": "verified_large_v3" if roster_verified else "unverified",
            "model": roster_fragments[0]["model"] if roster_fragments else None,
            "sources": [fragment["recording_id"] for fragment in roster_fragments],
            "evidence": roster_evidence,
        },
        "captains": [
            {
                "team": roster["team"],
                "team_label": roster["label"],
                "name": captain,
                "label": "kapitan potwierdzony przez użytkownika",
                "confidence": "high",
                "source": "informacja użytkownika",
                "evidence": [],
            }
            for roster, captain in zip(rosters, ("Wicu", "Dima"))
        ],
        "match_rule": {
            "id": "first_to_five",
            "status": rule_status,
            "description": "gra do pięciu goli/bramek, potem przerwa",
            "source": "zweryfikowany_large_v3" if rule_evidence else None,
            "confidence": (
                "medium"
                if any("prawek" in normalized_search_text(item["text"]) for item in rule_evidence)
                else ("high" if rule_evidence else "not_established")
            ),
            "model": rule_fragments[0]["model"] if rule_fragments else None,
            "evidence": rule_evidence,
        },
    }


def verify_session_context(
    recordings: list[dict[str, Any]],
    analyses: list[dict[str, Any]],
    run_root: Path,
    model: Path,
    *,
    force: bool,
) -> dict[str, Any]:
    fragments: list[dict[str, Any]] = []
    context_requests = [
        ("session_roster", "meczyk"),
        ("session_roster", "recorder"),
        ("five_goal_rule", None),
    ]
    for purpose, source_type in context_requests:
        fragment = find_context_fragment(
            recordings,
            analyses,
            purpose,
            source_type,
        )
        if fragment is None:
            continue
        fragments.append(
            verify_context_fragment(
                fragment,
                run_root,
                model,
                force=force,
            )
        )

    context = build_session_context(recordings, fragments)
    context["verification_fragments"] = fragments
    return context


def build_match_summaries(
    target_date: date,
    recordings: list[dict[str, Any]],
    pairs: list[dict[str, Any]],
    analyses: list[dict[str, Any]],
    timezone: ZoneInfo | None = None,
) -> list[dict[str, Any]]:
    timezone = timezone or ZoneInfo("Europe/Warsaw")
    analysis_by_id = {analysis["id"]: analysis for analysis in analyses}
    pairs_by_meczyk = {pair["meczyk"]: pair for pair in pairs}
    summaries: list[dict[str, Any]] = []

    for recording in recordings:
        if recording["source_type"] != "meczyk":
            continue
        analysis = analysis_by_id[recording["id"]]
        variant = analysis["recommended_variant"]
        events = analysis["variants"][variant]["events"]
        if not events["match_starts"] and not events["goals"]:
            continue
        pair = pairs_by_meczyk.get(recording["id"])
        recorder_goals: int | None = None
        agreement = None
        recorder_events: dict[str, Any] | None = None
        if pair:
            recorder_analysis = analysis_by_id[pair["recorder"]]
            recorder_variant = pair["selected_variants"]["recorder"]
            recorder_events = recorder_analysis["variants"][recorder_variant]["events"]
            recorder_goals = len(recorder_events["goals"])
            agreement = pair["event_similarity"]

        candidate_goals = [dict(goal) for goal in events["goals"]]
        pair_is_confirmed = bool(
            pair
            and pair["verification"] == "confirmed"
            and agreement is not None
            and agreement >= 0.8
        )
        unmatched_recorder_goals = annotate_goal_sources(
            candidate_goals,
            recorder_events["goals"] if pair_is_confirmed and recorder_events else None,
            meczyk_id=recording["id"],
            recorder_id=pair["recorder"] if pair_is_confirmed and pair else None,
        )
        goals = [goal for goal in candidate_goals if goal_is_auto_counted(goal)]
        pending_goals = [
            {
                **goal,
                "review_source_id": recording["id"],
                "review_source_role": "meczyk",
                "review_variant": variant,
            }
            for goal in candidate_goals
            if not goal_is_auto_counted(goal)
        ]
        pending_recorder_goals = [
            {
                **goal,
                "review_source_id": pair["recorder"],
                "review_source_role": "recorder",
                "review_variant": pair["selected_variants"]["recorder"],
                "source": pair["recorder"],
                "source_confidence": "single_source",
                "evidence_by_source": {
                    "recorder": goal.get("evidence", []),
                },
                "auto_counted": False,
                "automatic_count_reason": "recorder_only_unmatched_announcement",
            }
            for goal in unmatched_recorder_goals
        ]
        for goal in goals:
            goal["match_time_seconds"] = goal.get("match_seconds")
        for goal in pending_goals + pending_recorder_goals:
            goal["match_time_seconds"] = goal.get("match_seconds")

        last_goal_time = goals[-1]["recording_seconds"] if goals else None
        score_events = {**events, "goals": goals}
        score = final_score_evidence(score_events, len(goals))
        start_event = match_boundary(events["match_starts"])
        end_event = match_boundary(events["match_ends"], after=last_goal_time)
        start = (
            time_finding(
                recording,
                recording_seconds=start_event["recording_seconds"],
                target_date=target_date,
                timezone=timezone,
                status="confirmed_audio",
                source="komunikat audio",
                evidence=start_event["evidence"],
            )
            if start_event
            else time_finding(
                recording,
                recording_seconds=None,
                target_date=target_date,
                timezone=timezone,
                status="not_established",
                source="brak komunikatu start",
                evidence=None,
            )
        )
        end = (
            time_finding(
                recording,
                recording_seconds=end_event["recording_seconds"],
                target_date=target_date,
                timezone=timezone,
                status="confirmed_audio",
                source="komunikat audio",
                evidence=end_event["evidence"],
            )
            if end_event
            else time_finding(
                recording,
                recording_seconds=recording["audio"]["duration"],
                target_date=target_date,
                timezone=timezone,
                status="estimated_recording_boundary",
                source="granica końca nagrania",
                evidence=None,
            )
        )
        summaries.append(
            {
                "id": recording["id"],
                "date": target_date.isoformat(),
                "recording_name": recording["name"],
                "recording_start_datetime": recording.get("recording_start_datetime"),
                "pair_id": pair["id"] if pair else None,
                "pair_verification": pair["verification"] if pair else "missing",
                "meczyk_variant": variant,
                "recorder_variant": (
                    pair["selected_variants"]["recorder"] if pair else None
                ),
                "meczyk_goal_count": len(goals),
                "meczyk_detected_goal_count": len(candidate_goals),
                "recorder_goal_count": recorder_goals,
                "event_similarity": agreement,
                "final_score": score["value"] if score else None,
                "final_score_source": "wypowiedziany" if score else None,
                "final_score_confidence": "high" if score else None,
                "final_score_evidence": score["evidence"] if score else [],
                "start": start,
                "end": end,
                "goals": goals,
                "pending_goals": pending_goals,
                "pending_recorder_goals": pending_recorder_goals,
                "manual_review_goals": [],
                "roster_candidates": events["roster_candidates"],
                "captain_candidates": events["captain_candidates"],
            }
        )
    for index, summary in enumerate(
        sorted(
            summaries,
            key=lambda item: (
                item.get("recording_start_datetime") or "",
                item["id"],
            ),
        ),
        start=1,
    ):
        summary["match_number"] = index
    return sorted(summaries, key=lambda item: item["match_number"])


def attach_device_log_guidance(
    device_log: dict[str, Any],
    match_summaries: list[dict[str, Any]],
    recordings: list[dict[str, Any]],
    target_date: date,
    timezone: ZoneInfo,
) -> None:
    """Align DeviceLog replay goals with recordings and create search windows."""

    recordings_by_id = {recording["id"]: recording for recording in recordings}
    device_matches = device_log.get("matches", [])
    used_device_match_indexes: set[int] = set()
    mappings: list[dict[str, Any]] = []

    for summary in match_summaries:
        recording = recordings_by_id.get(summary["id"])
        summary["device_log"] = {
            "status": "not_available",
            "missing_goals": [],
            "goal_alignments": [],
        }
        if not recording or not device_matches:
            continue

        recording_start = recording_start_datetime(recording, target_date, timezone)
        if recording_start is None:
            summary["device_log"] = {
                "status": "recording_start_unavailable",
                "missing_goals": [],
                "goal_alignments": [],
            }
            continue
        recording_duration = float(recording.get("audio", {}).get("duration", 0))

        candidates: list[tuple[float, int, dict[str, Any], float]] = []
        for index, device_match in enumerate(device_matches):
            if index in used_device_match_indexes:
                continue
            try:
                device_start = parse_device_timestamp(
                    device_match["start"]["timestamp"],
                    timezone,
                )
            except (KeyError, TypeError, ValueError):
                continue
            start_offset = (device_start - recording_start).total_seconds()
            if start_offset < -DEVICE_LOG_START_TOLERANCE_SECONDS:
                continue
            if start_offset > recording_duration + DEVICE_LOG_START_TOLERANCE_SECONDS:
                continue
            try:
                device_end = device_match.get("end")
                end_offset = (
                    parse_device_timestamp(device_end["timestamp"], timezone)
                    - recording_start
                ).total_seconds()
                if end_offset < -DEVICE_LOG_START_TOLERANCE_SECONDS:
                    continue
            except (KeyError, TypeError, ValueError):
                pass
            candidates.append((abs(start_offset), index, device_match, start_offset))

        if not candidates:
            summary["device_log"] = {
                "status": "no_matching_device_match",
                "missing_goals": [],
                "goal_alignments": [],
            }
            continue

        _, device_match_index, device_match, start_offset = min(
            candidates,
            key=lambda item: item[0],
        )
        used_device_match_indexes.add(device_match_index)
        active_device_goals = [
            goal for goal in device_match.get("goals", []) if goal.get("active")
        ]
        audio_candidates: list[tuple[dict[str, Any], str]] = []
        for goal in summary.get("goals", []):
            if goal.get("recording_seconds") is not None:
                audio_candidates.append((goal, "confirmed"))
        for goal in summary.get("pending_goals", []):
            if goal.get("recording_seconds") is not None:
                audio_candidates.append((goal, "pending"))
        audio_candidates.sort(key=lambda item: item[0]["recording_seconds"])

        used_audio_indexes: set[int] = set()
        alignments: list[dict[str, Any]] = []
        missing_goals: list[dict[str, Any]] = []
        for device_goal in active_device_goals:
            try:
                device_goal_time = parse_device_timestamp(
                    device_goal["timestamp"],
                    timezone,
                )
            except (KeyError, TypeError, ValueError):
                continue
            recording_seconds = (
                device_goal_time - recording_start
            ).total_seconds()
            possible_audio = [
                (
                    abs(float(goal["recording_seconds"]) - recording_seconds),
                    index,
                    goal,
                    status,
                )
                for index, (goal, status) in enumerate(audio_candidates)
                if index not in used_audio_indexes
            ]
            matched_audio = min(possible_audio, default=None, key=lambda item: item[0])
            if (
                matched_audio is not None
                and matched_audio[0] <= DEVICE_LOG_GOAL_MATCH_TOLERANCE_SECONDS
            ):
                _, audio_index, audio_goal, audio_status = matched_audio
                used_audio_indexes.add(audio_index)
                alignments.append(
                    {
                        "status": "audio_candidate",
                        "side": device_goal["side"],
                        "device_event": device_goal,
                        "recording_seconds": round(recording_seconds, 3),
                        "audio_recording_seconds": audio_goal["recording_seconds"],
                        "audio_status": audio_status,
                        "audio_scorer": audio_goal.get("scorer"),
                        "delta_seconds": round(
                            float(audio_goal["recording_seconds"])
                            - recording_seconds,
                            3,
                        ),
                    }
                )
                continue

            if recording_seconds < -DEVICE_LOG_GOAL_SEARCH_AFTER_SECONDS:
                search_status = "outside_audio_recording"
                search_window = None
            elif recording_duration > 0 and recording_seconds > recording_duration:
                search_status = "outside_audio_recording"
                search_window = None
            else:
                search_status = "missing_audio_candidate"
                window_start = max(
                    recording_seconds - DEVICE_LOG_GOAL_SEARCH_BEFORE_SECONDS,
                    0,
                )
                window_end = recording_seconds + DEVICE_LOG_GOAL_SEARCH_AFTER_SECONDS
                if recording_duration > 0:
                    window_end = min(window_end, recording_duration)
                search_window = {
                    "from_seconds": round(window_start, 3),
                    "to_seconds": round(max(window_end, window_start + 1), 3),
                }

            missing = {
                "goal_number": device_goal.get("goal_number"),
                "side": device_goal["side"],
                "device_event": device_goal,
                "recording_seconds": round(recording_seconds, 3),
                "recording_datetime": iso_datetime(device_goal_time),
                "expected_score": device_goal.get("score_after"),
                "status": search_status,
                "search_window": search_window,
                "reason": "device_log_goal_without_audio_candidate",
                "review_source_id": summary["id"],
                "review_source_role": "device_log",
                "review_variant": summary.get("meczyk_variant", "neutral"),
            }
            missing_goals.append(missing)
            alignments.append(
                {
                    "status": search_status,
                    "side": device_goal["side"],
                    "device_event": device_goal,
                    "recording_seconds": round(recording_seconds, 3),
                    "search_window": search_window,
                }
            )

        extra_audio_goals = [
            {
                "recording_seconds": goal.get("recording_seconds"),
                "scorer": goal.get("scorer"),
                "status": status,
            }
            for index, (goal, status) in enumerate(audio_candidates)
            if index not in used_audio_indexes
        ]
        expected_score = device_match.get("final_score") or device_match.get("score")
        if not summary.get("final_score") and isinstance(expected_score, dict):
            my_score = expected_score.get("my")
            them_score = expected_score.get("them")
            if my_score is not None and them_score is not None:
                summary["final_score"] = f"{my_score}:{them_score}"
                summary["final_score_source"] = "device_log"
                summary["final_score_confidence"] = "high"
                summary["final_score_evidence"] = [
                    {
                        "source": "DeviceLog",
                        "match_number": device_match.get("match_number"),
                        "start": device_match.get("start"),
                        "end": device_match.get("end"),
                        "score": expected_score,
                    }
                ]
        summary["device_log"] = {
            "status": "matched",
            "match_number": device_match.get("match_number"),
            "start": device_match.get("start"),
            "end": device_match.get("end"),
            "recording_start_offset_seconds": round(start_offset, 3),
            "expected_score": expected_score,
            "expected_goal_count": device_match.get("goal_count", 0),
            "audio_candidate_goal_count": len(audio_candidates),
            "audio_confirmed_goal_count": len(summary.get("goals", [])),
            "missing_goal_count": len(missing_goals),
            "missing_goals": missing_goals,
            "goal_alignments": alignments,
            "extra_audio_goals": extra_audio_goals,
        }
        mappings.append(
            {
                "recording_id": summary["id"],
                "device_match_number": device_match.get("match_number"),
                "missing_goal_count": len(missing_goals),
            }
        )

    device_log["match_mappings"] = mappings
    device_log["matched_match_count"] = len(mappings)
    device_log["unmatched_match_count"] = max(
        len(device_matches) - len(used_device_match_indexes),
        0,
    )


def load_manual_confirmations(run_root: Path) -> list[dict[str, Any]]:
    path = run_root / "analysis" / "manual_confirmations.json"
    if not path.is_file():
        return []
    document = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(document, dict):
        document = document.get("confirmations", [])
    return [item for item in document if isinstance(item, dict)]


def find_pending_confirmation_goal(
    summary: dict[str, Any],
    confirmation: dict[str, Any],
) -> tuple[list[dict[str, Any]], int, dict[str, Any]] | None:
    clip_link = confirmation.get("clip_link")
    source_id = confirmation.get("source_id")
    recording_seconds = confirmation.get("recording_seconds")
    candidates: list[tuple[list[dict[str, Any]], int, dict[str, Any]]] = [
        (pending, index, goal)
        for key in ("pending_goals", "pending_recorder_goals")
        for pending in [summary.get(key, [])]
        for index, goal in enumerate(pending)
    ]
    device_pending = summary.get("device_log", {}).get("missing_goals", [])
    candidates.extend(
        (device_pending, index, goal)
        for index, goal in enumerate(device_pending)
    )

    if clip_link:
        exact_clip_matches = [
            candidate
            for candidate in candidates
            if candidate[2].get("review_clip", {}).get("clip_link") == clip_link
        ]
        if exact_clip_matches:
            return exact_clip_matches[0]

    scoped_candidates = [
        candidate
        for candidate in candidates
        if not source_id or candidate[2].get("review_source_id") == source_id
    ]
    if recording_seconds is not None:
        timed_matches = [
            candidate
            for candidate in scoped_candidates
            if abs(
                float(candidate[2].get("recording_seconds", -1))
                - float(recording_seconds)
            ) <= 0.01
        ]
        if len(timed_matches) == 1:
            return timed_matches[0]

    scorer = confirmation.get("scorer")
    if scorer:
        scorer_matches = [
            candidate
            for candidate in scoped_candidates
            if same_scorer(candidate[2].get("scorer"), scorer)
        ]
        return scorer_matches[0] if len(scorer_matches) == 1 else None

    return scoped_candidates[0] if len(scoped_candidates) == 1 else None


def find_existing_confirmation_goal(
    summary: dict[str, Any],
    confirmation: dict[str, Any],
) -> dict[str, Any] | None:
    scorer = confirmation.get("scorer")
    if not scorer:
        return None

    candidates = [
        goal
        for goal in summary.get("goals", [])
        if same_scorer(goal.get("scorer"), scorer)
    ]
    recording_seconds = confirmation.get("recording_seconds")
    if recording_seconds is not None:
        candidates = [
            goal
            for goal in candidates
            if abs(
                float(goal.get("recording_seconds", -1))
                - float(recording_seconds)
            ) <= 0.01
        ]

    if (
        confirmation.get("assist_status") == "confirmed_no_assist"
        or confirmation.get("assist") is None
    ):
        no_assist_candidates = [goal for goal in candidates if not goal.get("assist")]
        if no_assist_candidates:
            candidates = no_assist_candidates

    return candidates[0] if len(candidates) == 1 else None


def apply_confirmation_to_existing_goal(
    target: dict[str, Any],
    confirmation: dict[str, Any],
) -> None:
    if confirmation.get("scorer"):
        target["scorer"] = confirmation["scorer"]
        target["scorer_source"] = {
            "source": "potwierdzenie użytkownika",
            "confidence": "high",
        }
    assist_status = confirmation.get("assist_status")
    if assist_status == "needs_manual_review":
        target["assist"] = None
        target["assist_candidates"] = (
            [confirmation.get("assist_candidate")]
            if confirmation.get("assist_candidate")
            else []
        )
        target["assist_status"] = "manual_review_required"
        target["assist_review"] = confirmation.get("assist_review", {})
        target["assist_source"] = {
            "source": "ponowna transkrypcja large-v3",
            "confidence": "not_established",
        }
    elif assist_status == "confirmed_no_assist":
        target["assist"] = None
        target["assist_candidates"] = []
        target["assist_status"] = "confirmed_no_assist"
        target["assist_source"] = {
            "source": "potwierdzenie użytkownika po odsłuchu klipów 6–9",
            "confidence": "high",
        }
    elif "assist" in confirmation:
        target["assist"] = confirmation.get("assist")
        target["assist_candidates"] = (
            [confirmation["assist"]] if confirmation.get("assist") else []
        )
        target["assist_status"] = "confirmed_by_user"
        target["assist_source"] = {
            "source": "potwierdzenie użytkownika",
            "confidence": "high",
        }

    target["confidence"] = "high"
    target["source_confidence"] = "manual_user_confirmed"
    target["manual_confirmation_status"] = "confirmed_by_user"
    target["manual_confirmation"] = confirmation


def append_evidence(
    target: dict[str, Any],
    source_role: str,
    evidence: list[dict[str, Any]],
) -> None:
    target.setdefault("evidence_by_source", {}).setdefault(source_role, [])
    for item in evidence:
        if item not in target["evidence_by_source"][source_role]:
            target["evidence_by_source"][source_role].append(item)


def apply_manual_confirmations(
    match_summaries: list[dict[str, Any]],
    confirmations: list[dict[str, Any]],
) -> None:
    summaries_by_number = {
        summary["match_number"]: summary for summary in match_summaries
    }
    for summary in match_summaries:
        summary["manual_confirmations"] = []
        summary["manual_confirmation_errors"] = []

    for confirmation in confirmations:
        summary = summaries_by_number.get(confirmation.get("match_number"))
        if summary is None:
            continue
        pending_match = find_pending_confirmation_goal(summary, confirmation)
        if pending_match is None:
            if confirmation.get("resolution", "new_goal") == "duplicate_existing_goal":
                target = find_existing_confirmation_goal(summary, confirmation)
                if target is not None:
                    apply_confirmation_to_existing_goal(target, confirmation)
                    summary["manual_confirmations"].append(
                        {
                            **confirmation,
                            "status": "updated_existing_goal",
                        }
                    )
                    continue
            summary["manual_confirmation_errors"].append(
                {
                    **confirmation,
                    "error": "nie znaleziono oczekującej kandydatury",
                }
            )
            continue

        pending, pending_index, pending_goal = pending_match
        scorer = confirmation.get("scorer") or pending_goal.get("scorer")
        assist = confirmation.get("assist")
        assist_status = confirmation.get("assist_status")
        resolution = confirmation.get("resolution", "new_goal")
        source_role = pending_goal.get("review_source_role", "recorder")
        if resolution == "duplicate_existing_goal":
            if assist_status in {"needs_manual_review", "confirmed_no_assist"}:
                target = next(
                    (
                        goal
                        for goal in summary["goals"]
                        if same_scorer(goal.get("scorer"), scorer)
                        and (
                            confirmation.get("recording_seconds") is None
                            or abs(
                                float(goal.get("recording_seconds", -1))
                                - float(confirmation["recording_seconds"])
                            )
                            <= 0.01
                        )
                    ),
                    None,
                )
            else:
                target = next(
                    (
                        goal
                        for goal in summary["goals"]
                        if same_scorer(goal.get("scorer"), scorer)
                        and same_scorer(goal.get("assist"), assist)
                    ),
                    None,
                )
            if target is None:
                summary["manual_confirmation_errors"].append(
                    {
                        **confirmation,
                        "error": "nie znaleziono istniejącego gola do scalenia",
                    }
                )
                continue
            append_evidence(
                target,
                source_role,
                pending_goal.get("evidence", []),
            )
            target["source_confidence"] = "paired_and_user_confirmed"
            apply_confirmation_to_existing_goal(target, confirmation)
            pending.pop(pending_index)
            summary["manual_confirmations"].append(
                {
                    **confirmation,
                    "status": "applied_to_existing_goal",
                }
            )
            continue

        confirmed_goal = dict(pending_goal)
        confirmed_goal["scorer"] = scorer
        confirmed_goal["assist"] = assist
        confirmed_goal["assist_candidates"] = [assist] if assist else []
        confirmed_goal["type"] = confirmation.get(
            "type",
            pending_goal.get("type", "goal"),
        )
        if confirmed_goal["type"] == "own_goal":
            confirmed_goal["goal_type"] = "own_goal"
            confirmed_goal["own_goal_player"] = scorer
            confirmed_goal["assist"] = None
            confirmed_goal["assist_candidates"] = []
        confirmed_goal["confidence"] = "high"
        confirmed_goal["source_confidence"] = "manual_user_confirmed"
        confirmed_goal["manual_confirmation_status"] = "confirmed_by_user"
        confirmed_goal["manual_confirmation"] = confirmation
        confirmed_goal["confirmed_by_both_recordings"] = False
        confirmed_goal["auto_counted"] = True
        confirmed_goal["automatic_count_reason"] = "manual_user_confirmation"
        confirmed_goal["source"] = pending_goal.get("review_source_id")
        confirmed_goal["evidence_by_source"] = {
            source_role: pending_goal.get("evidence", []),
        }
        confirmed_goal["minute_source"] = {
            "source": f"ręczne potwierdzenie z {source_role}",
            "confidence": "high",
        }
        summary["goals"].append(confirmed_goal)
        pending.pop(pending_index)
        summary["goals"].sort(
            key=lambda goal: (
                goal.get("match_minute") is None,
                goal.get("match_minute") or 0,
                goal.get("recording_seconds") or 0,
            )
        )
        summary["meczyk_goal_count"] = len(summary["goals"])
        summary["manual_confirmations"].append(
            {
                **confirmation,
                "status": "added_as_confirmed_goal",
            }
        )

    for summary in match_summaries:
        summary["manual_confirmed_goal_count"] = len(
            summary.get("manual_confirmations", [])
        )
        if "device_log" in summary:
            summary["device_log"]["missing_goal_count"] = len(
                summary["device_log"].get("missing_goals", [])
            )
            summary["device_log"]["audio_confirmed_goal_count"] = len(
                summary.get("goals", [])
            )
        summary["manual_review_goals"] = [
            goal["review_clip"]
            for goal in (
                [
                    goal
                    for goal in summary.get("goals", [])
                    if goal.get("confidence") != "high"
                ]
                + summary.get("pending_goals", [])
                + summary.get("pending_recorder_goals", [])
                + summary.get("device_log", {}).get("missing_goals", [])
            )
            if goal.get("review_clip")
        ]


def organizational_recordings(
    recordings: list[dict[str, Any]],
    analyses: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    analysis_by_id = {analysis["id"]: analysis for analysis in analyses}
    result = []
    for recording in recordings:
        if recording["source_type"] != "meczyk":
            continue
        analysis = analysis_by_id[recording["id"]]
        variant = analysis["recommended_variant"]
        events = analysis["variants"][variant]["events"]
        if events["match_starts"] or events["goals"]:
            continue
        result.append(
            {
                "id": recording["id"],
                "name": recording["name"],
                "classification": "organizacyjne",
                "reason": "brak komunikatu start i brak rozpoznanych goli",
                "used_for": ["składy", "zasady gry", "kapitanowie"],
                "variant": variant,
                "roster_evidence": events["roster_candidates"],
                "captain_evidence": events["captain_candidates"],
            }
        )
    return result


def verify_missing_final_scores(
    match_summaries: list[dict[str, Any]],
    recordings: list[dict[str, Any]],
    pairs: list[dict[str, Any]],
    analyses: list[dict[str, Any]],
    run_root: Path,
    model: Path,
    *,
    force: bool,
) -> None:
    recordings_by_id = {recording["id"]: recording for recording in recordings}
    analyses_by_id = {analysis["id"]: analysis for analysis in analyses}
    pairs_by_id = {pair["id"]: pair for pair in pairs}

    for summary in match_summaries:
        if summary["final_score"] or not summary["goals"]:
            continue

        source_id = summary["id"]
        variant = summary["meczyk_variant"]
        pair = pairs_by_id.get(summary["pair_id"])
        if pair and pair["verification"] == "confirmed":
            source_id = pair["recorder"]
            variant = pair["selected_variants"]["recorder"]

        recording = recordings_by_id[source_id]
        events = analyses_by_id[source_id]["variants"][variant]["events"]
        if not events["goals"]:
            summary["score_verification"] = "no_goal_anchor"
            continue

        last_goal = events["goals"][-1]["recording_seconds"]
        clip_start = max(last_goal - 25, 0)
        directory = run_root / "verification" / summary["id"]
        clip = directory / f"{source_id}-{variant}-tail.wav"
        output = directory / f"{source_id}-{variant}-large-v3"
        transcript = Path(f"{output}.json")
        log_path = run_root / "logs" / f"{summary['id']}-score-verification.log"
        directory.mkdir(parents=True, exist_ok=True)

        if force or not transcript.is_file():
            clip_command = [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "warning",
                "-y",
                "-ss",
                f"{clip_start:.3f}",
                "-t",
                "90",
                "-i",
                recording[f"{variant}_path"],
                "-c:a",
                "pcm_s16le",
                str(clip),
            ]
            if not run_logged(clip_command, log_path):
                summary["score_verification"] = "clip_failed"
                continue
            transcribe_command = [
                "python3",
                str(TRANSCRIBER),
                str(clip),
                "--output",
                str(output),
                "--model",
                str(model),
                "--cpu",
                "--force",
            ]
            if not run_logged(transcribe_command, log_path):
                summary["score_verification"] = "transcription_failed"
                continue

        verification_document = json.loads(transcript.read_text(encoding="utf-8"))
        verification_events = extract(
            verification_document,
            f"{summary['id']}:score-verification",
        )
        candidates = [
            score
            for score in verification_events["scores"]
            if score["home"] + score["away"] == summary["meczyk_goal_count"]
        ]
        if candidates:
            score = candidates[-1]
            summary["final_score"] = f"{score['home']}:{score['away']}"
            summary["final_score_source"] = "zweryfikowany_large_v3"
            summary["final_score_confidence"] = "high"
            summary["final_score_evidence"] = [score["evidence"]]
            summary["score_verification"] = {
                "source_id": source_id,
                "variant": variant,
                "model": model.name,
                "clip_start_seconds": round(clip_start, 3),
                "evidence": score["evidence"],
            }
        else:
            summary["score_verification"] = "not_spoken_or_not_recognized"


def infer_scores_from_rule(
    match_summaries: list[dict[str, Any]],
    session_context: dict[str, Any],
) -> None:
    rule = session_context.get("match_rule", {})
    if rule.get("id") != "first_to_five" or rule.get("status") != "confirmed":
        return

    for summary in match_summaries:
        if summary.get("final_score") or len(summary["goals"]) != 8:
            continue
        summary["final_score"] = "5:3"
        summary["final_score_source"] = "wywnioskowany_z_reguly"
        summary["final_score_confidence"] = "medium"
        summary["final_score_evidence"] = rule.get("evidence", [])
        summary["score_inference"] = {
            "rule": rule["id"],
            "description": rule["description"],
            "evidence": rule.get("evidence", []),
        }


def create_goal_review_clips(
    match_summaries: list[dict[str, Any]],
    recordings: list[dict[str, Any]],
    run_root: Path,
    *,
    force: bool,
) -> None:
    """Export short listenable clips for candidates excluded from the score."""

    recordings_by_id = {recording["id"]: recording for recording in recordings}
    analysis_root = run_root / "analysis"
    review_root = analysis_root / "manual_review"
    review_root.mkdir(parents=True, exist_ok=True)

    for summary in match_summaries:
        reviews: list[dict[str, Any]] = []
        low_confidence_goals = [
            goal
            for goal in summary.get("goals", [])
            if goal.get("confidence") != "high"
            and goal.get("recording_seconds") is not None
        ]
        for goal in low_confidence_goals:
            goal.setdefault("review_source_id", summary["id"])
            goal.setdefault("review_source_role", "meczyk")
            goal.setdefault(
                "review_variant",
                summary.get("meczyk_variant", "neutral"),
            )
        pending_groups = (
            ("pending_goals", summary.get("pending_goals", [])),
            ("pending_recorder_goals", summary.get("pending_recorder_goals", [])),
            ("device_log_missing_goals", summary.get("device_log", {}).get("missing_goals", [])),
            ("low_confidence_goals", low_confidence_goals),
        )
        for group_name, pending_goals in pending_groups:
            for index, goal in enumerate(pending_goals, start=1):
                source_id = goal.get("review_source_id")
                recording = recordings_by_id.get(source_id)
                recording_seconds = goal.get("recording_seconds")
                if not recording or recording_seconds is None:
                    review = {
                        "status": "missing_audio_or_timestamp",
                        "source_id": source_id,
                        "source_role": goal.get("review_source_role"),
                        "scorer": goal.get("scorer"),
                    }
                    goal["review_clip"] = review
                    reviews.append(review)
                    continue

                search_window = goal.get("search_window")
                if group_name == "device_log_missing_goals" and not search_window:
                    review = {
                        "status": goal.get("status", "outside_audio_recording"),
                        "source_id": source_id,
                        "source_role": goal.get("review_source_role"),
                        "variant": goal.get("review_variant", "neutral"),
                        "side": goal.get("side"),
                        "expected_score": goal.get("expected_score"),
                    }
                    goal["review_clip"] = review
                    reviews.append(review)
                    continue

                variant = goal.get("review_variant", "neutral")
                input_path = recording.get(f"{variant}_path")
                if not input_path:
                    review = {
                        "status": "missing_audio_variant",
                        "source_id": source_id,
                        "source_role": goal.get("review_source_role"),
                        "variant": variant,
                        "scorer": goal.get("scorer"),
                    }
                    goal["review_clip"] = review
                    reviews.append(review)
                    continue

                if search_window:
                    clip_start = max(float(search_window["from_seconds"]), 0.0)
                    requested_duration = max(
                        float(search_window["to_seconds"]) - clip_start,
                        1.0,
                    )
                else:
                    clip_start = max(float(recording_seconds) - 8.0, 0.0)
                    requested_duration = 35.0
                duration = float(recording.get("audio", {}).get("duration", 0))
                clip_duration = requested_duration
                if duration > 0:
                    clip_duration = min(clip_duration, max(duration - clip_start, 1.0))
                scorer = slugify(str(goal.get("scorer") or "nierozpoznany"))
                role = slugify(str(goal.get("review_source_role") or "source"))
                if group_name == "low_confidence_goals":
                    role = "meczyk-goal"
                clip = review_root / (
                    f"match-{summary['match_number']:02d}-{role}-"
                    f"{index:02d}-{scorer}.m4a"
                )
                log_path = run_root / "logs" / f"{summary['id']}-manual-review.log"
                if force or not clip.is_file():
                    command = [
                        "ffmpeg",
                        "-hide_banner",
                        "-loglevel",
                        "warning",
                        "-y",
                        "-ss",
                        f"{clip_start:.3f}",
                        "-t",
                        f"{clip_duration:.3f}",
                        "-i",
                        str(input_path),
                        "-vn",
                        "-map_metadata",
                        "-1",
                        "-c:a",
                        "aac",
                        "-b:a",
                        "96k",
                        "-ar",
                        "16000",
                        "-ac",
                        "1",
                        str(clip),
                    ]
                    if not run_logged(command, log_path):
                        review = {
                            "status": "clip_failed",
                            "source_id": source_id,
                            "source_role": goal.get("review_source_role"),
                            "variant": variant,
                            "scorer": goal.get("scorer"),
                        }
                        goal["review_clip"] = review
                        reviews.append(review)
                        continue

                review = {
                    "status": "ready" if clip.is_file() else "clip_missing",
                    "source_id": source_id,
                    "source_role": goal.get("review_source_role"),
                    "variant": variant,
                    "scorer": goal.get("scorer"),
                    "from_seconds": round(clip_start, 3),
                    "duration_seconds": round(clip_duration, 3),
                    "clip_path": str(clip),
                    "clip_link": clip.relative_to(analysis_root).as_posix(),
                    "search_window": search_window,
                    "side": goal.get("side"),
                    "expected_score": goal.get("expected_score"),
                }
                goal["review_clip"] = review
                reviews.append(review)
        summary["manual_review_goals"] = reviews


def assign_review_numbers(
    match_summaries: list[dict[str, Any]],
    analysis_root: Path | None = None,
) -> list[dict[str, Any]]:
    """Give every listenable clip a stable number for conversational follow-up."""

    index: list[dict[str, Any]] = []
    for summary in match_summaries:
        for confirmation in summary.get("manual_confirmations", []):
            clip_link = confirmation.get("clip_link")
            if not clip_link:
                continue
            number = len(index) + 1
            original_clip_link = clip_link
            confirmation["review_number"] = number
            confirmation["audio_number"] = number
            clip_link = numbered_clip_link(
                clip_link,
                number,
                analysis_root,
            )
            confirmation["clip_link"] = clip_link
            for goal in summary.get("goals", []):
                nested = goal.get("manual_confirmation")
                if nested and nested.get("clip_link") == original_clip_link:
                    nested["clip_link"] = clip_link
                    nested["review_number"] = number
                    nested["audio_number"] = number
            index.append(
                {
                    "number": number,
                    "audio_number": number,
                    "match_number": summary["match_number"],
                    "source_id": confirmation.get("source_id"),
                    "scorer": confirmation.get("scorer"),
                    "assist": confirmation.get("assist"),
                    "type": confirmation.get("type", "goal"),
                    "status": confirmation.get("status", "confirmed_by_user"),
                    "resolution": confirmation.get("resolution"),
                    "user_note": confirmation.get("user_note"),
                    "clip_link": clip_link,
                }
            )

        for goal in summary.get("goals", []):
            if goal.get("confidence") == "high":
                continue
            clip = goal.get("review_clip", {})
            clip_link = clip.get("clip_link")
            if not clip_link:
                continue
            number = len(index) + 1
            clip["review_number"] = number
            clip["audio_number"] = number
            clip_link = numbered_clip_link(
                clip_link,
                number,
                analysis_root,
            )
            clip["clip_link"] = clip_link
            index.append(
                {
                    "number": number,
                    "audio_number": number,
                    "match_number": summary["match_number"],
                    "source_id": summary["id"],
                    "scorer": goal.get("scorer"),
                    "assist": goal.get("assist"),
                    "type": goal.get("type", "goal"),
                    "status": clip.get("status", "ready"),
                    "resolution": "low_confidence_goal",
                    "user_note": None,
                    "clip_link": clip_link,
                }
            )

        for goal in summary.get("pending_goals", []) + summary.get(
            "pending_recorder_goals", []
        ):
            clip = goal.get("review_clip", {})
            clip_link = clip.get("clip_link")
            if not clip_link:
                continue
            number = len(index) + 1
            clip["review_number"] = number
            clip["audio_number"] = number
            clip_link = numbered_clip_link(
                clip_link,
                number,
                analysis_root,
            )
            clip["clip_link"] = clip_link
            index.append(
                {
                    "number": number,
                    "audio_number": number,
                    "match_number": summary["match_number"],
                    "source_id": goal.get("review_source_id"),
                    "scorer": goal.get("scorer"),
                    "assist": goal.get("assist"),
                    "type": goal.get("type", "goal"),
                    "status": clip.get("status", "ready"),
                    "resolution": "manual_review_required",
                    "user_note": None,
                    "clip_link": clip_link,
                }
            )

        for goal in summary.get("device_log", {}).get("missing_goals", []):
            clip = goal.get("review_clip", {})
            clip_link = clip.get("clip_link")
            if not clip_link:
                continue
            number = len(index) + 1
            clip["review_number"] = number
            clip["audio_number"] = number
            clip_link = numbered_clip_link(
                clip_link,
                number,
                analysis_root,
            )
            clip["clip_link"] = clip_link
            index.append(
                {
                    "number": number,
                    "audio_number": number,
                    "match_number": summary["match_number"],
                    "source_id": goal.get("review_source_id"),
                    "scorer": None,
                    "assist": None,
                    "type": "goal",
                    "status": clip.get("status", "ready"),
                    "resolution": "device_log_search",
                    "side": goal.get("side"),
                    "expected_score": goal.get("expected_score"),
                    "user_note": None,
                    "clip_link": clip_link,
                }
            )
    return index


def numbered_clip_link(
    clip_link: str,
    number: int,
    analysis_root: Path | None,
) -> str:
    if analysis_root is None:
        return clip_link
    source = analysis_root / clip_link
    numbered = source.with_name(f"{number:02d}-{source.name}")
    if source.is_file() and not numbered.is_file():
        shutil.copy2(source, numbered)
    return numbered.relative_to(analysis_root).as_posix()


def render_report(
    target_date: date,
    recordings: list[dict[str, Any]],
    pairs: list[dict[str, Any]],
    unmatched: list[str],
    analyses: list[dict[str, Any]],
    match_summaries: list[dict[str, Any]],
    session_context: dict[str, Any] | None = None,
    organizational: list[dict[str, Any]] | None = None,
    manual_review: list[str] | None = None,
    manual_review_clips: list[dict[str, Any]] | None = None,
    device_log: dict[str, Any] | None = None,
) -> str:
    session_context = session_context or {}
    organizational = organizational or []
    manual_review = manual_review or []
    manual_review_clips = manual_review_clips or []
    device_log = device_log or {}

    def cell(value: Any, fallback: str = "—") -> str:
        if value is None or value == "":
            return fallback
        return str(value).replace("|", "\\|").replace("\n", " ")

    def time_cell(finding: dict[str, Any] | None) -> str:
        if not finding or not finding.get("time"):
            return "nierozpoznano"
        return (
            f"{finding['time']} "
            f"({finding.get('status', '—')}; {finding.get('source', '—')})"
        )

    def source_label(source: str | None) -> str:
        return {
            "wypowiedziany": "wypowiedziany w audio",
            "zweryfikowany_large_v3": "zweryfikowany large-v3",
            "wywnioskowany_z_reguly": "wywnioskowany z reguły",
            "device_log": "DeviceLog",
        }.get(source or "", "nierozpoznany")

    def goal_evidence(goal: dict[str, Any]) -> str:
        snippets = []
        for source_name in ("meczyk", "recorder"):
            evidence = goal.get("evidence_by_source", {}).get(source_name, [])
            if evidence:
                text = evidence[0].get("text", "")
                corrections = goal.get("own_goal_evidence_by_source", {}).get(
                    source_name,
                    [],
                )
                if corrections:
                    text += " [korekta: " + corrections[-1].get("text", "") + "]"
                snippets.append(f"{source_name}: {text}")
        if not snippets and goal.get("evidence"):
            snippets.append(str(goal["evidence"][0].get("text", "")))
        return cell(" / ".join(snippets), "brak dowodu tekstowego")

    lines = [
        f"# Pipeline nagrań meczowych — {target_date.isoformat()}",
        "",
        "Źródłem prawdy są lokalne transkrypcje audio w wariantach neutral i clean;",
        "pliki TXT z Downloads nie były kopiowane ani używane. Liczba słów po cleaningu",
        "nie jest dowodem wyższej jakości — wybór wariantu opiera się na zdarzeniach",
        "i zgodności sparowanych nagrań.",
        "",
        "## Pliki i pary",
        "",
        "| ID | Źródło | Długość | Kodek | Kanały | Profil |",
        "| --- | --- | ---: | --- | ---: | --- |",
    ]
    for recording in recordings:
        audio = recording["audio"]
        lines.append(
            f"| {recording['id']} | {recording['source_type']} | "
            f"{audio['duration'] / 60:.2f} min | {audio['codec']} | "
            f"{audio['channels']} | {recording.get('profile', '—')} |"
        )

    lines.extend(
        [
            "",
            "| Para | Meczyk | R | Różnica długości | Zgodność tekstu | Weryfikacja |",
            "| --- | --- | --- | ---: | ---: | --- |",
        ]
    )
    for pair in pairs:
        lines.append(
            f"| {pair['id']} | {pair['meczyk']} | {pair['recorder']} | "
            f"{pair['duration_difference']:.1f} s | "
            f"{pair.get('text_similarity', 0) * 100:.1f}% | "
            f"{pair.get('verification', '—')} |"
        )
    if not pairs:
        lines.append("| — | — | — | — | — | — |")
    lines.append("")
    lines.extend(["## DeviceLog", ""])
    if device_log.get("status") in {None, "not_found"}:
        lines.append("Nie znaleziono dzisiejszego pliku 6aa*.json.")
    else:
        lines.append(
            f"Status: {cell(device_log.get('status'))}; "
            f"zdarzenia: {device_log.get('event_count', 0)}; "
            f"dopasowane mecze: {device_log.get('matched_match_count', 0)}."
        )
        for file in device_log.get("files", []):
            lines.append(
                f"- `{Path(file.get('path', file.get('destination', ''))).name}` — "
                f"{file.get('status', '—')}; kanał event_code: "
                f"{file.get('channel_id', '—')}."
            )
        for summary in match_summaries:
            guidance = summary.get("device_log", {})
            if guidance.get("status") != "matched":
                continue
            expected = guidance.get("expected_score", {})
            missing_count = guidance.get("missing_goal_count", 0)
            lines.append(
                f"- Mecz {summary['match_number']}: DeviceLog przewiduje "
                f"MY {expected.get('my', '—')} : ONI {expected.get('them', '—')}; "
                f"brakujące okna audio: {missing_count}."
            )
    lines.append("")
    operator = session_context.get("recording_operator")
    if operator:
        lines.extend(
            [
                "Nagrywający nagrań R*: "
                f"{operator['name']} (pewność: {operator['confidence']}; "
                f"źródło: {operator['source']}).",
                "",
            ]
        )
    lines.append("Nieposiadające pary: " + (", ".join(unmatched) if unmatched else "brak"))

    lines.extend(["", "## Nagrania organizacyjne", ""])
    if organizational:
        lines.append("| ID | Klasyfikacja | Powód | Wykorzystanie |")
        lines.append("| --- | --- | --- | --- |")
        for item in organizational:
            lines.append(
                f"| {item['id']} | {item['classification']} | "
                f"{cell(item['reason'])} | {cell(', '.join(item['used_for']))} |"
            )
    else:
        lines.append("Brak nagrań organizacyjnych.")

    lines.extend(
        [
            "",
            "## Porównanie A/B",
            "",
            "| ID | Profil | Segmenty N/C | Słowa N/C | Δ słów | Gole N/C | "
            "Wyniki N/C | Zgodność A/B | Wskazanie |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
        ]
    )
    for analysis in analyses:
        neutral = analysis["variants"]["neutral"]
        clean = analysis["variants"]["clean"]
        comparison = analysis.get("comparison", {})
        lines.append(
            f"| {analysis['id']} | {analysis.get('profile', '—')} | "
            f"{neutral['segments']}/{clean['segments']} | "
            f"{neutral['words']}/{clean['words']} | "
            f"{comparison.get('word_delta_clean_minus_neutral', clean['words'] - neutral['words']):+d} | "
            f"{neutral['goals']}/{clean['goals']} | "
            f"{neutral['scores']}/{clean['scores']} | "
            f"{analysis['similarity'] * 100:.1f}% | "
            f"{analysis['recommended_variant']} |"
        )

    lines.extend(
        [
            "",
            "## Składy sesji i kapitanowie",
            "",
        ]
    )
    roster_verification = session_context.get("roster_verification", {})
    lines.append(
        "Weryfikacja składów: "
        f"{roster_verification.get('status', 'unverified')} "
        f"({cell(roster_verification.get('model'))})."
    )
    lines.append("")
    for roster in session_context.get("rosters", []):
        lines.append(f"### {roster['label']}")
        lines.append("")
        lines.append("| Osoba/rola | Status | Pewność |")
        lines.append("| --- | --- | --- |")
        for member in roster["members"]:
            name = member.get("name") or member.get("raw") or "nierozpoznane"
            if member.get("alias") and member["alias"].casefold() not in name.casefold():
                name = f"{name} ({member['alias']})"
            if member.get("candidate_names"):
                name += " — kandydaci: " + "/".join(member["candidate_names"])
            lines.append(
                f"| {cell(name)} | {cell(member.get('status'))} | "
                f"{cell(member.get('confidence'))} |"
            )
        lines.append("")
    lines.append("| Drużyna | Kapitan | Pewność | Źródło |")
    lines.append("| --- | --- | --- | --- |")
    for captain in session_context.get("captains", []):
        lines.append(
            f"| {captain.get('team_label', captain.get('team', '—'))} | "
            f"{cell(captain.get('label'))} | "
            f"{cell(captain.get('confidence'))} | {cell(captain.get('source'))} |"
        )

    lines.extend(
        [
            "",
            "## Zestawienie meczów",
            "",
            "| # | Data | Start | Koniec | Wynik | Źródło wyniku | Meczyk/R | "
            "Potwierdzenie zdarzeń |",
            "| ---: | --- | --- | --- | --- | --- | --- | --- |",
        ]
    )
    for summary in match_summaries:
        recorder_goals = (
            str(summary["recorder_goal_count"])
            if summary["recorder_goal_count"] is not None
            else "—"
        )
        confirmed_goals = sum(
            bool(goal.get("confirmed_by_both_recordings"))
            for goal in summary["goals"]
        )
        lines.append(
            f"| {summary['match_number']} | {summary['date']} | "
            f"{time_cell(summary.get('start'))} | {time_cell(summary.get('end'))} | "
            f"{cell(summary.get('final_score'), 'nierozpoznany')} | "
            f"{source_label(summary.get('final_score_source'))} | "
            f"{summary['meczyk_goal_count']}/{recorder_goals} | "
            f"{confirmed_goals}/{summary['meczyk_goal_count']} |"
        )

    lines.extend(["", "## Gole i asysty", ""])
    for summary in match_summaries:
        lines.extend(
            [
                f"### Mecz {summary['match_number']} — {summary['recording_name']}",
                "",
                f"Start: {time_cell(summary.get('start'))}; "
                f"koniec: {time_cell(summary.get('end'))}.",
                "",
                f"Wynik: {cell(summary.get('final_score'), 'nierozpoznany')} "
                f"({source_label(summary.get('final_score_source'))}; "
                f"pewność: {cell(summary.get('final_score_confidence'))}).",
                "",
                "| # | Minuta | Strzelec | Asysta | Meczyk/R | Pewność | Klip | Dowód |",
                "| ---: | ---: | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for index, goal in enumerate(summary["goals"], start=1):
            confirmation = (
                "tak — potwierdzone ręcznie"
                if goal.get("manual_confirmation_status") == "confirmed_by_user"
                else "tak — Meczyk + R"
                if goal.get("confirmed_by_both_recordings")
                else "tak — powtórzone w ≤5 s"
                if goal.get("goal_confirmation") == "repeated_within_5_seconds"
                else "nie — do ręcznej weryfikacji"
            )
            assist = goal.get("assist") or "brak/nie rozpoznano"
            scorer = goal.get("scorer")
            if goal.get("type") == "own_goal" and scorer:
                scorer = f"{scorer} (samobój)"
            clip_link = goal.get("review_clip", {}).get("clip_link")
            clip = (
                f"[odsłuchaj]({clip_link})"
                if goal.get("confidence") != "high" and clip_link
                else "—"
            )
            lines.append(
                f"| {index} | {cell(goal.get('match_minute'))} | "
                f"{cell(scorer, 'nierozpoznany')} | {cell(assist)} | "
                f"{confirmation} | {cell(goal.get('confidence'))} | "
                f"{clip} | {goal_evidence(goal)} |"
            )
        if not summary["goals"]:
            lines.append("| — | — | nierozpoznany | brak/nie rozpoznano | — | — | — | — |")
        lines.append("")

    lines.extend(["## Reguła wyniku", ""])
    rule = session_context.get("match_rule", {})
    lines.append(
        f"{cell(rule.get('description'), 'Reguła nieustalona')}: "
        f"{cell(rule.get('status'), 'unconfirmed')} "
        f"(pewność: {cell(rule.get('confidence'))})."
    )
    for evidence in rule.get("evidence", []):
        lines.append(
            f"- {cell(evidence.get('from'))}–{cell(evidence.get('to'))}: "
            f"{cell(evidence.get('text'))}"
        )

    lines.extend(["", "## Klipy do odsłuchu", ""])
    if manual_review_clips:
        for clip in manual_review_clips:
            scorer = clip.get("scorer") or "nierozpoznany"
            if clip.get("type") == "own_goal":
                scorer = f"{scorer} (samobój)"
            description = clip.get("user_note") or scorer
            if clip.get("assist") and not clip.get("user_note"):
                description += f", asysta {clip['assist']}"
            lines.append(
                f"{clip['number']}. [Audio {clip['number']} — "
                f"Mecz {clip['match_number']} — {cell(description)}]"
                f"({clip['clip_link']})"
            )
    else:
        lines.append("Brak klipów do odsłuchu.")

    lines.extend(["", "## Potwierdzenia ręczne", ""])
    manual_confirmations = [
        confirmation
        for summary in match_summaries
        for confirmation in summary.get("manual_confirmations", [])
        if confirmation.get("status")
    ]
    if manual_confirmations:
        for confirmation in manual_confirmations:
            scorer = cell(confirmation.get("scorer"), "nierozpoznany")
            assist = confirmation.get("assist") or "brak/nie rozpoznano"
            resolution = confirmation.get("resolution", "new_goal")
            action = (
                "scalono z istniejącym golem"
                if resolution == "duplicate_existing_goal"
                else "dodano jako potwierdzony gol"
            )
            link = confirmation.get("clip_link")
            review_number = confirmation.get("review_number")
            listen = f" (klip {review_number})" if review_number else ""
            lines.append(
                f"- Mecz {confirmation.get('match_number')}: {scorer}, "
                f"asysta: {cell(assist)} — {action}{listen}."
            )
    else:
        lines.append("Brak ręcznych potwierdzeń.")

    lines.extend(["", "## Dane do ręcznego potwierdzenia", ""])
    if manual_review:
        lines.extend(f"- {item}" for item in manual_review)
    else:
        lines.append("Brak dodatkowych pozycji.")

    lines.extend(["", "## Ścieżki artefaktów", ""])
    lines.append("Raport JSON: `analysis/report.json`; raport Markdown: `analysis/report.md`.")
    return "\n".join(lines).rstrip() + "\n"


def build_manual_review(
    match_summaries: list[dict[str, Any]],
    session_context: dict[str, Any],
) -> list[str]:
    items: list[str] = []
    for summary in match_summaries:
        number = summary["match_number"]
        if summary.get("end", {}).get("status") == "estimated_recording_boundary":
            items.append(
                f"Mecz {number}: koniec oszacowany z granicy nagrania "
                "(brak komunikatu końca)."
            )
        if summary.get("final_score_source") == "wywnioskowany_z_reguly":
            items.append(
                f"Mecz {number}: wynik {summary['final_score']} wynika z reguły "
                "gry do pięciu i ośmiu wykrytych goli; nie został wypowiedziany."
            )
        if summary.get("pair_verification") not in {"confirmed"}:
            items.append(
                f"Mecz {number}: para Meczyk/R ma status "
                f"{summary.get('pair_verification')}; zdarzenia nie są wspólnie "
                "potwierdzone."
            )
        for missing in summary.get("device_log", {}).get("missing_goals", []):
            side = "MY" if missing.get("side") == "my" else "ONI"
            clip = missing.get("review_clip", {})
            link = clip.get("clip_link")
            review_number = clip.get("review_number")
            listen = (
                f" [klip {review_number}: odsłuchaj fragment]({link})"
                if link
                else ""
            )
            window = missing.get("search_window") or {}
            if window:
                window_label = (
                    f"{window.get('from_seconds', 0):.1f}–"
                    f"{window.get('to_seconds', 0):.1f} s nagrania"
                )
            else:
                window_label = "poza zakresem nagrania"
            items.append(
                f"Mecz {number}: DeviceLog wskazuje brakujący gol {side} "
                f"około {missing.get('recording_seconds', 0):.1f} s "
                f"({window_label}); wynik po evencie: "
                f"{missing.get('expected_score', {})}.{listen}"
            )
        for pending in summary.get("pending_goals", []) + summary.get(
            "pending_recorder_goals", []
        ):
            scorer = pending.get("scorer") or "nierozpoznany"
            reason = pending.get(
                "automatic_count_reason",
                "single_or_spread_announcement",
            )
            evidence = pending.get("evidence", [])
            evidence_text = evidence[0].get("text") if evidence else "brak"
            clip = pending.get("review_clip", {})
            link = clip.get("clip_link")
            review_number = clip.get("review_number")
            listen = (
                f" [klip {review_number}: odsłuchaj fragment]({link})"
                if link
                else ""
            )
            items.append(
                f"Mecz {number}: kandydat gola {scorer} ({reason}) nie został "
                f"wliczony automatycznie; dowód: „{evidence_text}”.{listen}"
            )
        for index, goal in enumerate(summary["goals"], start=1):
            manually_confirmed = (
                goal.get("manual_confirmation_status") == "confirmed_by_user"
            )
            if goal.get("type") == "own_goal" and not manually_confirmed:
                initial = goal.get("initial_scorer_call") or "nieustalonego zawodnika"
                own_goal_player = goal.get("own_goal_player") or goal.get("scorer")
                items.append(
                    f"Mecz {number}, gol {index}: początkowo rozpoznano „{initial} "
                    f"gol”, następnie jako „{own_goal_player} samobój”; "
                    "wymaga ręcznego potwierdzenia sposobu zapisu."
                )
            if goal.get("assist_status") == "confirmed_no_assist":
                continue
            if not goal.get("assist") and goal.get("type") != "own_goal":
                if goal.get("assist_status") == "manual_review_required":
                    candidate = goal.get("assist_candidates", ["nieznany"])[0]
                    clips = goal.get("assist_review", {}).get("clips", [])
                    links = " ".join(
                        f"[klip {clip.get('number', '?')}]({clip.get('clip_link')})"
                        for clip in clips
                        if clip.get("clip_link")
                    )
                    items.append(
                        f"Mecz {number}, gol {index}: kandydat asysty "
                        f"{candidate} nie został potwierdzony przez large-v3; "
                        f"wymaga ręcznego odsłuchu. {links}".strip()
                    )
                    continue
                items.append(
                    f"Mecz {number}, gol {index}: asysta brak/nie rozpoznano; "
                    "wymaga ręcznego odsłuchu."
                )

    for roster in session_context.get("rosters", []):
        for member in roster.get("members", []):
            if member.get("status") in {"ambiguous", "unresolved"}:
                items.append(
                    f"{roster['label']}: {member.get('raw')} — "
                    "niejednoznaczne przypisanie osoby."
                )
    for captain in session_context.get("captains", []):
        if not captain.get("name"):
            items.append(
                f"{captain.get('team_label', captain.get('team'))}: "
                "kapitan nieustalony."
            )
    return items


def main() -> int:
    arguments = parse_arguments()
    source = arguments.source.expanduser().resolve()
    output_root = arguments.output_root.expanduser().resolve()
    if not source.is_dir():
        return fail(f"nie znaleziono katalogu źródłowego: {source}")
    if arguments.sample_seconds is not None and arguments.sample_seconds < 1:
        return fail("--sample-seconds musi być większe od zera")
    if arguments.prepare_workers < 1:
        return fail("--prepare-workers musi być większe od zera")
    if arguments.max_pair_duration_difference < 0:
        return fail("--max-pair-duration-difference nie może być ujemne")
    model = arguments.model.expanduser().resolve()
    verification_model = arguments.verification_model.expanduser().resolve()
    if arguments.stage in {"transcribe", "all"} and not model.is_file():
        return fail(f"nie znaleziono modelu wsadowego: {model}")
    if arguments.stage in {"analyze", "all"} and not verification_model.is_file():
        return fail(f"nie znaleziono modelu weryfikacyjnego: {verification_model}")

    try:
        timezone = ZoneInfo(arguments.timezone)
        target_date = (
            date.fromisoformat(arguments.date)
            if arguments.date
            else datetime.now(timezone).date()
        )
    except ZoneInfoNotFoundError:
        return fail(f"nieznana strefa czasowa: {arguments.timezone}")
    except ValueError:
        return fail("--date musi mieć format YYYY-MM-DD")

    run_root = output_root / target_date.isoformat()
    manifest_path = run_root / "manifest.json"
    try:
        if arguments.stage in {"collect", "all"}:
            manifest_path, manifest = collect(
                source,
                output_root,
                target_date,
                timezone,
                force=arguments.force,
                dry_run=False,
            )
        elif manifest_path.is_file():
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        else:
            return fail(f"brak manifestu: {manifest_path}; najpierw uruchom etap collect")

        if arguments.stage == "collect":
            print(f"Zebrano {manifest['audio_count']} nagrań. Manifest: {manifest_path}")
            return 0

        state_path = run_root / "pipeline.json"
        if arguments.stage in {"transcribe", "analyze"}:
            if not state_path.is_file():
                return fail(f"brak stanu: {state_path}; najpierw uruchom etap prepare")
            state = json.loads(state_path.read_text(encoding="utf-8"))
            recordings = state["recordings"]
            pairs = state["pairs"]
            unmatched = state["unmatched"]
        else:
            recordings = []
            for record in manifest["files"]:
                if record["kind"] != "audio":
                    continue
                path = Path(record["destination"])
                recordings.append(
                    {
                        "id": slugify(path.stem),
                        "name": path.name,
                        "source_type": record["source_type"],
                        "path": str(path),
                        "audio": probe_audio(path),
                    }
                )
            recordings.sort(key=lambda item: item["id"])
            pairs, unmatched = pair_recordings(
                recordings,
                arguments.max_pair_duration_difference,
            )
            state = {"recordings": recordings, "pairs": pairs, "unmatched": unmatched}
            state_path.write_text(
                json.dumps(state, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

        annotate_recording_operators(recordings)
        for recording in recordings:
            recording_start_datetime(recording, target_date, timezone)

        if arguments.stage in {"prepare", "all"}:
            profiles = {
                recording["id"]: (
                    arguments.meczyk_profile
                    if recording["source_type"] == "meczyk"
                    else arguments.recorder_profile
                )
                for recording in recordings
            }
            prepare_recordings(
                recordings,
                run_root,
                profiles,
                force=arguments.force,
                workers=arguments.prepare_workers,
            )
            state_path.write_text(
                json.dumps(state, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        if arguments.stage == "prepare":
            print(f"Przygotowano {len(recordings)} nagrań. Stan: {state_path}")
            return 0

        if arguments.stage in {"transcribe", "all"}:
            for recording in recordings:
                for variant in ("neutral", "clean"):
                    transcribe_variant(
                        recording,
                        run_root,
                        variant,
                        sample_seconds=arguments.sample_seconds,
                        cpu=arguments.cpu,
                        force=arguments.force,
                        model=model,
                    )
            state_path.write_text(
                json.dumps(state, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        if arguments.stage == "transcribe":
            print(f"Transkrybowano {len(recordings)} nagrań. Stan: {state_path}")
            return 0

        attach_existing_transcript_paths(recordings, run_root)
        analyses = [analyze_recording(recording, run_root) for recording in recordings]
        apply_recorder_identity_to_own_goals(recordings, analyses)
        recordings_by_id = {recording["id"]: recording for recording in recordings}
        analyses_by_id = {analysis["id"]: analysis for analysis in analyses}
        for pair in pairs:
            pair["variant_text_similarities"] = pair_variant_text_similarities(
                pair,
                recordings_by_id,
            )
            verify_pair_and_select_variants(pair, analyses_by_id)
        session_context = verify_session_context(
            recordings,
            analyses,
            run_root,
            verification_model,
            force=arguments.force,
        )
        match_summaries = build_match_summaries(
            target_date,
            recordings,
            pairs,
            analyses,
            timezone,
        )
        device_log = load_device_logs(manifest, target_date, timezone)
        attach_device_log_guidance(
            device_log,
            match_summaries,
            recordings,
            target_date,
            timezone,
        )
        create_goal_review_clips(
            match_summaries,
            recordings,
            run_root,
            force=arguments.force,
        )
        manual_confirmations = load_manual_confirmations(run_root)
        apply_manual_confirmations(match_summaries, manual_confirmations)
        if not arguments.no_score_verification:
            verify_missing_final_scores(
                match_summaries,
                recordings,
                pairs,
                analyses,
                run_root,
                verification_model,
                force=arguments.force,
            )
        infer_scores_from_rule(match_summaries, session_context)
        manual_review_clips = assign_review_numbers(
            match_summaries,
            run_root / "analysis",
        )
        organizational = organizational_recordings(recordings, analyses)
        manual_review = build_manual_review(match_summaries, session_context)
        state_path.write_text(
            json.dumps(state, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        report = {
            "date": target_date.isoformat(),
            "transcription": {
                "model": str(model),
                "model_name": model.name,
                "sample_seconds": arguments.sample_seconds,
                "cpu_requested": arguments.cpu,
                "verification_model": str(verification_model),
                "score_verification_enabled": not arguments.no_score_verification,
            },
            "recordings": recordings,
            "pairs": pairs,
            "unmatched": unmatched,
            "organizational_recordings": organizational,
            "session": session_context,
            "ab": analyses,
            "matches": match_summaries,
            "device_log": device_log,
            "manual_confirmations": manual_confirmations,
            "manual_review_clips": manual_review_clips,
            "manual_review": manual_review,
        }
        report_root = run_root / "analysis"
        report_root.mkdir(parents=True, exist_ok=True)
        report_json = report_root / "report.json"
        report_markdown = report_root / "report.md"
        report_json.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        report_markdown.write_text(
            render_report(
                target_date,
                recordings,
                pairs,
                unmatched,
                analyses,
                match_summaries,
                session_context,
                organizational,
                manual_review,
                manual_review_clips,
                device_log,
            ),
            encoding="utf-8",
        )
        print(f"Raport: {report_markdown}")
        print(f"Dane: {report_json}")
        return 0
    except (KeyError, json.JSONDecodeError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        return fail(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
