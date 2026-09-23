#!/usr/bin/env python3
"""Suggest roster matches for names in timestamped Whisper segments."""

from __future__ import annotations

from collections import Counter
from difflib import SequenceMatcher
import re
import time
import unicodedata
from typing import Any


WORD_RE = re.compile(r"[^\W\d_]+", re.UNICODE)
PARENTHETICAL_RE = re.compile(r"\(([^()]*)\)")
ROLE_ALIASES = {"bramkarz", "bramkarzem", "goalkeeper"}
MAX_NGRAM_WORDS = 3
TOP_CANDIDATES = 3
MIN_FUZZY_SCORE = 65.0
CHARACTER_WEIGHT = 0.7
PHONETIC_WEIGHT = 0.3


def _player_identity_key(player_id: Any, player_name: str) -> tuple[str, str]:
    if player_id is not None:
        return "id", str(player_id)
    return "name", normalize_text(player_name)


def normalize_text(value: str) -> str:
    folded = unicodedata.normalize("NFKD", value.casefold().replace("ł", "l"))
    without_marks = "".join(
        character for character in folded
        if not unicodedata.combining(character)
    )
    return re.sub(r"[^a-z0-9]+", " ", without_marks).strip()


def phonetic_form(value: str) -> str:
    """Apply small Polish spelling equivalences for a second similarity signal."""

    normalized = normalize_text(value)
    for old, new in (("rz", "z"), ("ch", "h"), ("sz", "s"), ("cz", "c"), ("dz", "z")):
        normalized = normalized.replace(old, new)
    sound_groups = {
        "b": "p", "p": "p",
        "d": "t", "t": "t",
        "g": "k", "k": "k",
        "w": "f", "f": "f",
        "z": "s", "s": "s",
        "y": "i", "i": "i",
        "u": "u", "o": "o",
    }
    result: list[str] = []
    previous = ""
    for character in normalized:
        sound = sound_groups.get(character, character)
        if sound == " ":
            if result and result[-1] != " ":
                result.append(sound)
            previous = ""
            continue
        if sound == previous:
            continue
        result.append(sound)
        previous = sound
    return "".join(result).strip()


def similarity_scores(raw: str, alias: str) -> tuple[float, float, float]:
    raw_normalized = normalize_text(raw)
    alias_normalized = normalize_text(alias)
    if raw_normalized == alias_normalized:
        return 100.0, 100.0, 100.0

    character_score = SequenceMatcher(
        None, raw_normalized, alias_normalized, autojunk=False
    ).ratio() * 100
    raw_phonetic = phonetic_form(raw)
    alias_phonetic = phonetic_form(alias)
    phonetic_score = SequenceMatcher(
        None, raw_phonetic, alias_phonetic, autojunk=False
    ).ratio() * 100
    final_score = (
        CHARACTER_WEIGHT * character_score
        + PHONETIC_WEIGHT * phonetic_score
    )
    return round(final_score, 1), round(character_score, 1), round(phonetic_score, 1)


def _player_aliases(players: list[dict[str, Any]]) -> list[dict[str, Any]]:
    aliases: list[dict[str, Any]] = []
    for player in players:
        name = str(player.get("name") or "").strip()
        if not name:
            continue
        values: list[tuple[str, str]] = [(name, "full_name")]
        nickname = str(player.get("nickname") or "").strip()
        if nickname:
            values.append((nickname, "nickname"))
        parentheticals = list(PARENTHETICAL_RE.finditer(name))
        if parentheticals:
            prefix = name[:parentheticals[0].start()].strip()
            if prefix:
                values.append((prefix, "name_without_parenthetical"))
            for match in parentheticals:
                alias = match.group(1).strip()
                if normalize_text(alias) not in ROLE_ALIASES:
                    values.append((alias, "parenthetical_alias"))

        seen: set[str] = set()
        for value, source in values:
            normalized = normalize_text(value)
            if not normalized or normalized in seen:
                continue
            seen.add(normalized)
            aliases.append(
                {
                    "player_key": _player_identity_key(player.get("id"), name),
                    "player_id": player.get("id"),
                    "player_name": name,
                    "alias": value,
                    "normalized_alias": normalized,
                    "word_count": len(normalized.split()),
                    "alias_source": source,
                }
            )
    return aliases


def _segment_milliseconds(segment: dict[str, Any], edge: str) -> int | None:
    offsets = segment.get("offsets") or {}
    value = offsets.get(edge)
    if isinstance(value, (int, float)):
        return int(value)

    timestamps = segment.get("timestamps") or {}
    value = timestamps.get(edge)
    if not isinstance(value, str):
        return None
    parts = value.replace(",", ".").split(":")
    try:
        if len(parts) == 3:
            seconds = int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
        elif len(parts) == 2:
            seconds = int(parts[0]) * 60 + float(parts[1])
        else:
            seconds = float(value)
    except ValueError:
        return None
    return round(seconds * 1000)


def _candidate_band(score: float) -> str:
    if score >= 90:
        return "strong"
    if score >= 80:
        return "probable"
    if score >= MIN_FUZZY_SCORE:
        return "review"
    return "weak"


def _rank_phrase(
    raw: str,
    phrase_word_count: int,
    aliases: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    phrase_normalized = normalize_text(raw)
    if not phrase_normalized:
        return []
    compact_length = len(phrase_normalized.replace(" ", ""))
    by_player: dict[Any, dict[str, Any]] = {}
    for alias in aliases:
        if alias["word_count"] != phrase_word_count:
            continue
        if phrase_normalized != alias["normalized_alias"] and compact_length < 4:
            continue
        score, character_score, phonetic_score = similarity_scores(raw, alias["alias"])
        candidate = {
            "player_id": alias["player_id"],
            "player_name": alias["player_name"],
            "matched_alias": alias["alias"],
            "alias_source": alias["alias_source"],
            "score": score,
            "character_score": character_score,
            "phonetic_score": phonetic_score,
            "score_band": _candidate_band(score),
        }
        previous = by_player.get(alias["player_key"])
        if previous is None or candidate["score"] > previous["score"]:
            by_player[alias["player_key"]] = candidate

    return sorted(
        by_player.values(),
        key=lambda candidate: (
            -candidate["score"],
            candidate["player_name"].casefold(),
            str(candidate["player_id"]),
        ),
    )[:TOP_CANDIDATES]


def _mention_status(best: float, margin: float) -> str:
    if best >= 90 and margin >= 10:
        return "strong"
    if best >= 80 and margin >= 8:
        return "likely"
    if best >= MIN_FUZZY_SCORE:
        return "ambiguous_or_review"
    return "unknown"


def _remove_resolved_subspans(mentions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[int, list[dict[str, Any]]] = {}
    for mention in mentions:
        grouped.setdefault(mention["segment_index"], []).append(mention)

    selected: list[dict[str, Any]] = []
    for segment_mentions in grouped.values():
        ordered = sorted(
            segment_mentions,
            key=lambda mention: (
                -(mention["text_end_char"] - mention["text_start_char"]),
                -mention["best_score"],
                mention["text_start_char"],
            ),
        )
        kept: list[dict[str, Any]] = []
        for mention in ordered:
            mention_candidates = {
                _player_identity_key(candidate["player_id"], candidate["player_name"])
                for candidate in mention["candidates"]
            }
            resolved_inside_longer_span = any(
                longer["text_start_char"] <= mention["text_start_char"]
                and longer["text_end_char"] >= mention["text_end_char"]
                and longer["text_end_char"] - longer["text_start_char"]
                > mention["text_end_char"] - mention["text_start_char"]
                and longer["status"] in {"strong", "likely"}
                and _player_identity_key(
                    longer["candidates"][0]["player_id"],
                    longer["candidates"][0]["player_name"],
                ) in mention_candidates
                for longer in kept
            )
            if not resolved_inside_longer_span:
                kept.append(mention)
        selected.extend(kept)

    return sorted(
        selected,
        key=lambda mention: (mention["segment_index"], mention["text_start_char"]),
    )


def match_transcript_to_players(
    transcript_document: dict[str, Any],
    players: list[dict[str, Any]],
    *,
    recording_id: str,
    transcript_path: str,
) -> dict[str, Any]:
    """Return timestamped mention spans with their top roster candidates."""

    started_at = time.perf_counter()
    aliases = _player_aliases(players)
    segments = transcript_document.get("transcription", [])
    if not isinstance(segments, list):
        segments = []

    mentions: list[dict[str, Any]] = []
    for segment_index, segment in enumerate(segments, start=1):
        if not isinstance(segment, dict):
            continue
        text = str(segment.get("text") or "")
        tokens = list(WORD_RE.finditer(text))
        for token_start in range(len(tokens)):
            for width in range(1, min(MAX_NGRAM_WORDS, len(tokens) - token_start) + 1):
                token_end = token_start + width - 1
                char_start = tokens[token_start].start()
                char_end = tokens[token_end].end()
                raw = text[char_start:char_end]
                candidates = _rank_phrase(raw, width, aliases)
                if not candidates or candidates[0]["score"] < MIN_FUZZY_SCORE:
                    continue
                best_score = candidates[0]["score"]
                second_score = candidates[1]["score"] if len(candidates) > 1 else 0.0
                start_ms = _segment_milliseconds(segment, "from")
                end_ms = _segment_milliseconds(segment, "to")
                mentions.append(
                    {
                        "raw": raw,
                        "normalized": normalize_text(raw),
                        "segment_index": segment_index,
                        "segment_start_ms": start_ms,
                        "segment_end_ms": end_ms,
                        "segment_start_seconds": (
                            round(start_ms / 1000, 3) if start_ms is not None else None
                        ),
                        "text_start_char": char_start,
                        "text_end_char": char_end,
                        "token_start": token_start + 1,
                        "token_end": token_end + 1,
                        "transcript_segment": text.strip(),
                        "best_score": best_score,
                        "second_score": second_score,
                        "margin": round(best_score - second_score, 1),
                        "status": _mention_status(best_score, best_score - second_score),
                        "candidates": candidates,
                    }
                )

    mentions = _remove_resolved_subspans(mentions)
    best_mentions: Counter[tuple[str, str]] = Counter()
    candidate_mentions: Counter[tuple[str, str]] = Counter()
    player_names: dict[tuple[str, str], tuple[Any, str]] = {}
    for mention in mentions:
        if mention["candidates"]:
            best = mention["candidates"][0]
            best_key = _player_identity_key(best["player_id"], best["player_name"])
            best_mentions[best_key] += 1
            player_names[best_key] = (best["player_id"], best["player_name"])
        for candidate in mention["candidates"]:
            candidate_key = _player_identity_key(
                candidate["player_id"], candidate["player_name"]
            )
            candidate_mentions[candidate_key] += 1
            player_names[candidate_key] = (
                candidate["player_id"], candidate["player_name"]
            )

    ranked_players = [
        {
            "player_id": player_names[player_key][0],
            "player_name": player_names[player_key][1],
            "top_candidate_mentions": best_mentions[player_key],
            "top_3_candidate_mentions": candidate_mentions[player_key],
        }
        for player_key in player_names
    ]
    ranked_players.sort(
        key=lambda item: (
            -item["top_candidate_mentions"],
            -item["top_3_candidate_mentions"],
            item["player_name"].casefold(),
        )
    )

    return {
        "recording_id": recording_id,
        "transcript_json": transcript_path,
        "matching_elapsed_ms": round((time.perf_counter() - started_at) * 1000, 2),
        "segments_scanned": len(segments),
        "candidate_mentions": len(mentions),
        "ranked_players": ranked_players,
        "mentions": mentions,
    }
