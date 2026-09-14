#!/usr/bin/env python3
"""Extract structured match-event candidates from whisper.cpp JSON output."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


WORD = r"[0-9A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż_-]+"
NAME_PHRASE = rf"{WORD}(?:\s+{WORD})?"
ASSIST_GOAL_RE = re.compile(
    rf"\b(?P<assist>{WORD})\s*,?\s*(?:asyst\w*|assist\w*)\s*,?\s*"
    rf"(?P<scorer>{NAME_PHRASE})\s*,?\s*(?:gol|goal)\b",
    re.IGNORECASE,
)
ASSIST_RE = re.compile(
    rf"\b(?P<assist>{WORD})\s*,?\s*(?:asyst\w*|assist\w*)\b",
    re.IGNORECASE,
)
GOAL_RE = re.compile(
    rf"\b(?P<scorer>{WORD})\s*,?\s*(?:gol|goal)\b",
    re.IGNORECASE,
)
IMPLICIT_ASSIST_GOAL_RE = re.compile(
    rf"\b(?P<assist>{WORD})\s*,?\s+(?P<scorer>{WORD})\s*,?\s+(?:gol|goal)\b",
    re.IGNORECASE,
)
OWN_GOAL_RE = re.compile(
    rf"\b(?P<player>{WORD}?)(?:\s+|(?=samob[óo]j))samob[óo]j\w*\b",
    re.IGNORECASE,
)
GENERIC_OWN_GOAL_RE = re.compile(r"\bsamob[óo]j\w*\b", re.IGNORECASE)
SCORE_RE = re.compile(r"(?<!\d)(?P<home>\d{1,2})\s*[-:]\s*(?P<away>\d{1,2})(?!\d)")
START_RE = re.compile(r"\b(zaczynamy|start|gotowi|lecimy)\b", re.IGNORECASE)
END_RE = re.compile(r"\b(koniec|kończymy|stop)\b", re.IGNORECASE)
ROSTER_RE = re.compile(
    r"\b(skład|drużyn\w*|team\w*|wybier\w*|biorę|bierę|wybrał)\b",
    re.IGNORECASE,
)
CAPTAIN_RE = re.compile(r"\bkapitan\w*\b", re.IGNORECASE)
INVALID_SCORERS = {
    "być",
    "jest",
    "mógł",
    "musi",
    "może",
    "nie",
    "powinien",
    "przyciśnij",
    "to",
}
NAME_ALIASES = {
    "barcelona": "Kamil (Barcelona)",
    "barcelonego": "Kamil (Barcelona)",
    "baca": "Baca",
    "czemu": "Przemo",
    "dig": "Milik",
    "inter": "Mati",
    "kesz": "Cash",
    "li": "Milik",
    "league": "Milik",
    "ligol": "Milik",
    "link": "Milik",
    "matti": "Mati",
    "matty": "Mati",
    "maty": "Mati",
    "mati cash": "Cash",
    "t-cash": "Cash",
    "mili": "Milik",
    "nieco": "Wicu",
    "paczek": "Płaczek",
    "placzek": "Płaczek",
    "przemek": "Przemo",
    "przemu": "Przemo",
    "paca": "Baca",
    "płaca": "Baca",
    "placa": "Baca",
    "stawicu": "Wicu",
    "szestawicu": "Wicu",
    "vico": "Wicu",
    "wico": "Wicu",
    "wice": "Wicu",
    "wicy": "Wicu",
    "wicso": "Wicu",
    "kamil": "Kamil (Marcelo)",
    "kamil barcelona": "Kamil (Barcelona)",
    "kamil barcelonego": "Kamil (Barcelona)",
    "kamil nowy": "Kamil (Barcelona)",
}
KNOWN_PLAYERS = {
    "Baca",
    "Cash",
    "Damian",
    "Daniel",
    "Dominik",
    "Kamil (Barcelona)",
    "Kamil (Marcelo)",
    "Mati",
    "Max",
    "Milik",
    "Przemo",
    "Płaczek",
    "Szymon",
    "Wicu",
}
REPEATED_GOAL_CONFIRMATION_WINDOW = 5.0
MIN_REPEATED_GOAL_ANNOUNCEMENTS = 2


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Wyciąga kandydatów goli, asyst, wyników i granic meczu.",
    )
    parser.add_argument("input", type=Path, help="JSON utworzony przez whisper.cpp")
    parser.add_argument("-o", "--output", type=Path)
    parser.add_argument("--source-id", help="identyfikator nagrania")
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"Błąd: {message}", file=sys.stderr)
    return 2


def timestamp_seconds(value: str) -> float:
    hours, minutes, seconds = value.replace(",", ".").split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def display_name(value: str | None) -> str | None:
    if not value:
        return None
    normalized = re.sub(r"[\s,.!?:;]+", " ", value).strip().casefold()
    if normalized in NAME_ALIASES:
        return NAME_ALIASES[normalized]

    # whisper.cpp czasami rozdziela jedno imię na dwa tokeny, np. „Mi Link”.
    # Alias ostatniego tokenu jest bezpieczniejszy niż zachowanie takiej frazy.
    tokens = normalized.split()
    if len(tokens) > 1 and tokens[-1] in NAME_ALIASES:
        return NAME_ALIASES[tokens[-1]]
    return normalized.title()


def same_scorer(left: str | None, right: str | None) -> bool:
    if not left or not right:
        return left == right
    left_name = display_name(left).casefold()
    right_name = display_name(right).casefold()
    distinct_kamil_names = {"kamil (barcelona)", "kamil (marcelo)"}
    if left_name in distinct_kamil_names and right_name in distinct_kamil_names:
        return left_name == right_name

    left_tokens = left_name.split()
    right_tokens = right_name.split()
    return left_tokens == right_tokens or left_tokens[0] == right_tokens[0]


def valid_scorer(value: str | None) -> bool:
    return bool(value and len(value) > 1 and value.casefold() not in INVALID_SCORERS)


def detected_own_goal_player(text: str) -> str | None:
    for match in OWN_GOAL_RE.finditer(text):
        player = display_name(match.group("player"))
        if player in KNOWN_PLAYERS:
            return player
    return None


def apply_own_goal_corrections(
    goals: list[dict[str, Any]],
    corrections: list[dict[str, Any]],
    *,
    correction_window: float = 30,
) -> None:
    for correction in corrections:
        candidate = next(
            (
                goal
                for goal in reversed(goals)
                if 0
                <= correction["recording_seconds"] - goal["recording_seconds"]
                <= correction_window
            ),
            None,
        )
        if candidate is None:
            continue

        candidate.setdefault("own_goal_evidence", []).append(correction["evidence"])
        candidate.setdefault("own_goal_announcement_times", []).append(
            correction["recording_seconds"]
        )
        player = correction.get("player")
        if not player:
            if candidate.get("type") == "own_goal":
                candidate["evidence"].append(correction["evidence"])
            continue

        if candidate.get("type") != "own_goal":
            previous_scorer = candidate.get("scorer")
            if previous_scorer and not same_scorer(previous_scorer, player):
                candidate["initial_scorer_call"] = previous_scorer
            candidate["type"] = "own_goal"
            candidate["goal_type"] = "own_goal"
            candidate["own_goal_player"] = player
            candidate["scorer"] = player
            candidate["assist"] = None
            candidate["assist_candidates"] = []
            candidate["confidence"] = "medium"

        for evidence in candidate["own_goal_evidence"]:
            if evidence not in candidate["evidence"]:
                candidate["evidence"].append(evidence)


def prepare_text(text: str) -> str:
    result = re.sub(r"\basystami\b", "asysta", text, flags=re.IGNORECASE)
    result = re.sub(
        rf"\b(?:asysta|assista|assistami)({WORD})\b",
        r"asysta \1",
        result,
        flags=re.IGNORECASE,
    )
    result = re.sub(
        rf"\b({WORD}?)(?:asyst|assist)(\w*)\b",
        lambda match: f"{match.group(1)} asysta" if match.group(1) else match.group(0),
        result,
        flags=re.IGNORECASE,
    )
    result = re.sub(
        rf"\b({WORD}?)(?:gol|goal)\b",
        r"\1 gol",
        result,
        flags=re.IGNORECASE,
    )
    return re.sub(r"\s+", " ", result).strip()


def segment_time(segment: dict[str, Any]) -> tuple[float, float]:
    timestamps = segment["timestamps"]
    return timestamp_seconds(timestamps["from"]), timestamp_seconds(timestamps["to"])


def event_time(segment: dict[str, Any]) -> float:
    start, finish = segment_time(segment)
    return finish if finish - start > 10 else start


def merge_goal(
    goals: list[dict[str, Any]],
    candidate: dict[str, Any],
    *,
    deduplication_window: float = 45,
    repeated_announcement_window: float = 120,
) -> None:
    candidate.setdefault("announcement_times", [candidate["recording_seconds"]])
    candidate["announcement_count"] = len(candidate["announcement_times"])

    for existing in reversed(goals):
        time_difference = (
            candidate["recording_seconds"] - existing["recording_seconds"]
        )
        if time_difference > repeated_announcement_window:
            break
        kamil_variant_confirmation = (
            time_difference <= REPEATED_GOAL_CONFIRMATION_WINDOW
            and {
                candidate["scorer"].casefold(),
                existing["scorer"].casefold(),
            }
            == {"kamil (barcelona)", "kamil (marcelo)"}
        )
        if not same_scorer(candidate["scorer"], existing["scorer"]):
            if not kamil_variant_confirmation:
                continue

        if kamil_variant_confirmation:
            existing["scorer"] = "Kamil (Barcelona)"
            existing["confidence"] = "high"

        if time_difference > deduplication_window:
            candidate_texts = {
                prepare_text(str(item["text"])).casefold()
                for item in candidate["evidence"]
            }
            existing_texts = {
                prepare_text(str(item["text"])).casefold()
                for item in existing["evidence"]
            }
            repeated_text = bool(candidate_texts & existing_texts)
            same_assist = bool(
                candidate["assist"]
                and existing["assist"]
                and candidate["assist"] == existing["assist"]
            )
            if not (repeated_text and same_assist):
                continue

        existing["evidence"].extend(candidate["evidence"])
        existing.setdefault(
            "announcement_times", [existing["recording_seconds"]]
        ).extend(candidate["announcement_times"])
        existing["announcement_count"] = len(existing["announcement_times"])
        if candidate["assist"] and candidate["assist"] not in existing["assist_candidates"]:
            existing["assist_candidates"].append(candidate["assist"])
        if existing["assist"] is None and candidate["assist"]:
            existing["assist"] = candidate["assist"]
        existing["confidence"] = "high" if existing["assist"] else "medium"
        return

    goals.append(candidate)


def repeated_announcement_cluster(
    times: list[float],
    *,
    window: float = REPEATED_GOAL_CONFIRMATION_WINDOW,
) -> list[float]:
    ordered = sorted(float(value) for value in times)
    for index, start in enumerate(ordered):
        cluster = [value for value in ordered[index:] if value - start <= window]
        if len(cluster) >= MIN_REPEATED_GOAL_ANNOUNCEMENTS:
            return cluster
    return []


def annotate_goal_confirmation(goals: list[dict[str, Any]]) -> None:
    for goal in goals:
        announcement_times = list(goal.get("announcement_times", []))
        announcement_times.extend(goal.get("own_goal_announcement_times", []))
        cluster = repeated_announcement_cluster(announcement_times)
        goal["goal_announcement_count"] = len(announcement_times)
        goal["goal_confirmation_count"] = len(cluster)
        if cluster:
            goal["goal_confirmation"] = "repeated_within_5_seconds"
            goal["goal_confirmation_window_seconds"] = round(
                max(cluster) - min(cluster), 3
            )
            goal["needs_manual_review"] = False
        else:
            goal["goal_confirmation"] = "single_or_spread_announcement"
            goal["goal_confirmation_window_seconds"] = None
            goal["needs_manual_review"] = True


def assign_matches(
    goals: list[dict[str, Any]],
    starts: list[dict[str, Any]],
) -> None:
    start_times = [candidate["recording_seconds"] for candidate in starts]
    for goal in goals:
        applicable = [value for value in start_times if value <= goal["recording_seconds"]]
        if applicable:
            start = applicable[-1]
            goal["match_index"] = start_times.index(start) + 1
            goal["match_seconds"] = round(goal["recording_seconds"] - start, 3)
            goal["match_minute"] = int(goal["match_seconds"] // 60) + 1
        else:
            goal["match_index"] = 1
            goal["match_seconds"] = None
            goal["match_minute"] = None


def extract(document: dict[str, Any], source_id: str) -> dict[str, Any]:
    goals: list[dict[str, Any]] = []
    scores: list[dict[str, Any]] = []
    starts: list[dict[str, Any]] = []
    ends: list[dict[str, Any]] = []
    roster_candidates: list[dict[str, Any]] = []
    captain_candidates: list[dict[str, Any]] = []
    own_goal_corrections: list[dict[str, Any]] = []
    pending_assist: tuple[str, float] | None = None

    for segment in document.get("transcription", []):
        raw_text = str(segment.get("text", "")).strip()
        text = prepare_text(raw_text)
        start, finish = segment_time(segment)
        timestamp = event_time(segment)
        evidence = {
            "from": segment["timestamps"]["from"],
            "to": segment["timestamps"]["to"],
            "text": raw_text,
        }

        if GENERIC_OWN_GOAL_RE.search(text):
            own_goal_corrections.append(
                {
                    "player": detected_own_goal_player(text),
                    "recording_seconds": round(timestamp, 3),
                    "evidence": evidence,
                }
            )

        if START_RE.search(text) and (
            not starts or timestamp - starts[-1]["recording_seconds"] >= 300
        ):
            starts.append(
                {
                    "recording_seconds": timestamp,
                    "evidence": evidence,
                }
            )
        if END_RE.search(text):
            ends.append(
                {
                    "recording_seconds": timestamp,
                    "evidence": evidence,
                }
            )
        if ROSTER_RE.search(text):
            roster_candidates.append(evidence)
        if CAPTAIN_RE.search(text):
            captain_candidates.append(evidence)

        for score_match in SCORE_RE.finditer(text):
            scores.append(
                {
                    "home": int(score_match.group("home")),
                    "away": int(score_match.group("away")),
                    "recording_seconds": timestamp,
                    "evidence": evidence,
                }
            )

        pair_matches = list(ASSIST_GOAL_RE.finditer(text))
        if pair_matches:
            for match in pair_matches:
                assist = display_name(match.group("assist"))
                scorer = display_name(match.group("scorer"))
                if not valid_scorer(scorer):
                    continue
                merge_goal(
                    goals,
                    {
                        "type": "goal",
                        "scorer": scorer,
                        "assist": assist,
                        "assist_candidates": [assist] if assist else [],
                        "recording_seconds": round(timestamp, 3),
                        "confidence": "high",
                        "evidence": [evidence],
                    },
                )
            pending_assist = None
            continue

        implicit_pair_matches = list(IMPLICIT_ASSIST_GOAL_RE.finditer(text))
        accepted_implicit_pair = False
        for match in implicit_pair_matches:
            assist = display_name(match.group("assist"))
            scorer = display_name(match.group("scorer"))
            if (
                assist not in KNOWN_PLAYERS
                or scorer not in KNOWN_PLAYERS
                or assist == scorer
            ):
                continue
            merge_goal(
                goals,
                {
                    "type": "goal",
                    "scorer": scorer,
                    "assist": assist,
                    "assist_candidates": [assist],
                    "recording_seconds": round(timestamp, 3),
                    "confidence": "medium",
                    "evidence": [evidence],
                },
            )
            accepted_implicit_pair = True
        if accepted_implicit_pair:
            pending_assist = None
            continue

        goal_matches = list(GOAL_RE.finditer(text))
        if goal_matches:
            for match in goal_matches:
                scorer = display_name(match.group("scorer"))
                if not valid_scorer(scorer):
                    continue
                assist = None
                if pending_assist and timestamp - pending_assist[1] <= 20:
                    assist = pending_assist[0]
                merge_goal(
                    goals,
                    {
                        "type": "goal",
                        "scorer": scorer,
                        "assist": assist,
                        "assist_candidates": [assist] if assist else [],
                        "recording_seconds": round(timestamp, 3),
                        "confidence": "high" if assist else "medium",
                        "evidence": [evidence],
                    },
                )
            pending_assist = None
            continue

        assist_match = ASSIST_RE.search(text)
        if assist_match:
            pending_assist = (display_name(assist_match.group("assist")) or "", finish)

    apply_own_goal_corrections(goals, own_goal_corrections)
    annotate_goal_confirmation(goals)
    assign_matches(goals, starts)
    return {
        "source_id": source_id,
        "goals": goals,
        "scores": scores,
        "match_starts": starts,
        "match_ends": ends,
        "roster_candidates": roster_candidates,
        "captain_candidates": captain_candidates,
        "own_goal_corrections": own_goal_corrections,
    }


def main() -> int:
    arguments = parse_arguments()
    input_path = arguments.input.expanduser().resolve()
    output_path = (
        arguments.output.expanduser().resolve()
        if arguments.output
        else input_path.with_name(f"{input_path.stem}.events.json")
    )

    if not input_path.is_file():
        return fail(f"nie znaleziono pliku: {input_path}")

    try:
        document = json.loads(input_path.read_text(encoding="utf-8"))
        result = extract(document, arguments.source_id or input_path.stem)
    except (json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        return fail(f"niepoprawny JSON transkrypcji: {error}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Utworzono: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
