# Football App

Ruby on Rails web application.

## Requirements

- macOS
- Homebrew
- asdf `0.15.0` or newer
- Ruby plugin for asdf
- SQLite

The project pins Ruby in `.tool-versions`:

```sh
ruby 4.0.5
```

Rails is locked in `Gemfile`:

```sh
rails 8.1.3
```

## First-Time Setup

Install the asdf Ruby plugin if it is not already installed:

```sh
asdf plugin add ruby
```

Update plugin definitions so asdf can see the current Ruby releases:

```sh
asdf plugin update ruby
```

Install the project Ruby version:

```sh
asdf install ruby 4.0.5
```

If Ruby compilation picks up a Conda or Mambaforge compiler on macOS, rebuild with Apple/Homebrew tools explicitly:

```sh
env -u CFLAGS -u CPPFLAGS -u LDFLAGS \
  PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin" \
  CC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" \
  CXX="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++" \
  AR="/usr/bin/ar" \
  NM="/usr/bin/nm" \
  RANLIB="/usr/bin/ranlib" \
  STRIP="/usr/bin/strip" \
  RUBY_CONFIGURE_OPTS="--disable-yjit --disable-zjit --disable-install-doc" \
  asdf install ruby 4.0.5
```

Install gems:

```sh
bundle install
```

Prepare the database:

```sh
bin/rails db:prepare
```

## Running the App

Start the development server:

```sh
bin/rails server
```

Open:

```sh
http://127.0.0.1:3000
```

## Apple Shortcuts Vote Invites

The vote invite API is intended for a private Apple Shortcut that sends SMS messages to active players after a match.

Configure an API token for the Rails app:

```sh
FOOTBALL_APP_API_TOKEN="change-me"
```

In Apple Shortcuts:

1. Add a "Get Contents of URL" action.
2. Set the URL to `https://your-app.example.com/api/vote_invites`. The endpoint automatically selects the latest finished Match Day in the active season.
3. Set the method to `GET`.
4. Add the request header `Authorization` with value `Bearer change-me`.
5. Parse the JSON response.
6. Repeat over `vote_invites`.
7. For each item, use "Send Message" with `phone` as the recipient and `sms_body` as the message text.

The response shape is:

```json
{
  "vote_invites": [
    {
      "name": "Player One",
      "phone": "+48123456789",
      "sms_body": "Czesc Player One, zaglosuj na MVP i DEF: https://your-app.example.com/votes/player-token"
    }
  ]
}
```

The bearer token protects the API endpoint used by the Shortcut. It is not a player vote access token. Each `sms_body` contains a player-specific, single-use voting URL. Voting remains open for the latest finished Match Day until a newer Match Day is finished in the same season.

## Match Data Import API

The protected API supports a read-before-write workflow for importing match-day data:

```sh
curl -H "Authorization: Bearer $FOOTBALL_APP_API_TOKEN" \
  "https://your-app.example.com/api/players"

curl -H "Authorization: Bearer $FOOTBALL_APP_API_TOKEN" \
  "https://your-app.example.com/api/seasons/active"
```

`GET /api/players` returns the player catalog ordered by name. Optional filters are
`search`, `active`, and `approval_status`. `GET /api/seasons/active` returns the
currently active season or `404` when no active season exists. Both endpoints require
the same Bearer token as the import endpoint.

After resolving player identities and receiving an explicit confirmation, send the
match-day payload to `POST /api/match_imports`. The importer creates the match day,
per-match rosters, goals, assists, scores, and finished-match performance data in one
transaction.

## Common Commands

Clean a speech recording before transcription (requires FFmpeg):

```sh
python3 script/clean_audio.py input.m4a \
  --output tmp/audio/input.clean.wav \
  --compressed-output tmp/audio/input.clean.mp3
```

The WAV is a 16 kHz mono master. The optional MP3 is encoded at 64 kb/s for
transcription services with upload-size limits. Use `--profile light` when the
voice already sounds clear or `--profile strong` only for especially noisy
recordings. The script preserves pauses so transcript timestamps still match
the source recording.

Transcribe the cleaned WAV locally with the full Whisper large-v3 model:

```sh
python3 script/transcribe_audio.py tmp/audio/input.clean.wav
```

The local whisper.cpp binary and model are stored under `.local/whisper.cpp`.
Transcription uses Polish, Metal acceleration, beam search, and conservative
Silero VAD settings that suppress hallucinations during silence while retaining
short calls. Rolling text context is disabled so a bad phrase cannot propagate
through later Bluetooth dropouts. It produces TXT, SRT, and JSON files. Pass
`--duration 60` for a one-minute test. Apply a player-name glossary in a
separate correction pass; an initial prompt conflicts with this script's
anti-hallucination mode because whisper.cpp uses the same context budget for
both features.

Run the development pipeline for recordings added to `~/Downloads` today:

```sh
python3 script/match_audio_pipeline.py
```

The pipeline selects audio whose local modification date is today and whose
name starts with `Meczyk-` or `R`. TXT files in
`Downloads` are deliberately ignored because they are not reliable references.
Audio files are copied to
`tmp/match_audio/YYYY-MM-DD`, which is ignored by Git. It pairs `Meczyk` and
`R` recordings by duration, reports missing counterparts, prepares neutral
and cleaned WAVs, transcribes both, and writes Markdown plus JSON comparison
reports. It verifies proposed pairs by transcript similarity and compares the
goal/assist sequences from both audio sources. Existing TXT files are never
used to score or select a cleaner variant. `Meczyk` uses the `bluetooth` cleaner
profile; `R` uses the milder
`recorder` profile because it is already compressed and its stereo channels
contain the same signal.

Useful development stages:

```sh
python3 script/match_audio_pipeline.py --stage collect
python3 script/match_audio_pipeline.py --stage prepare
python3 script/match_audio_pipeline.py --stage transcribe --cpu
python3 script/match_audio_pipeline.py --stage analyze
```

Etap `prepare` domyślnie przetwarza dwa niezależne nagrania równolegle przez
FFmpeg (`--prepare-workers 2`). Wyniki neutral/clean pozostają deterministyczne;
liczbę workerów można zmienić parametrem, np. `--prepare-workers 1`.

All full-file transcriptions default to the local full `ggml-large-v3.bin`
model, for both neutral/original and cleaned variants of every audio file.
Short context verification uses the same full large-v3 model. Pass
`--model PATH` or `--verification-model PATH` only when an intentional model
override is needed. Each pipeline transcript stores a model marker; an
existing transcript without a matching marker is transcribed again instead of
being silently reused. Each transcribe run also writes per-file wall-clock
times and the actual device used to `transcription_timings.json`. The analysis
also uses it on short context clips for the
session roster/rule and, when needed, around a missing final score; use
`--no-score-verification` only to skip the score-tail pass. It parses the
recording hour from each `Meczyk-... o HH:MM` filename and adds the audio offset
to produce local match datetimes. Start/end findings carry an explicit status:
an audio message is `confirmed_audio`, while the end of a file is
`estimated_recording_boundary`. Recordings with neither a start message nor a
goal are reported as organizational recordings and are not counted as matches.
An extracted goal is counted automatically only when the goal announcement is
repeated within five seconds or the same event is independently matched in the
paired Meczyk/R recordings. Single announcements, announcements spread beyond
five seconds, and unmatched recorder-only calls remain manual-review candidates;
the pipeline exports short audio clips under `analysis/manual_review/` and links
to them from a numbered clip index in the Markdown and JSON reports. Candidate transcript evidence and the
confirmation window are retained in JSON, so a background `gol` call does not
silently change the score. Assist evidence is kept separate and is never
invented when it is not clear.
Human decisions can be persisted in
`tmp/match_audio/YYYY-MM-DD/analysis/manual_confirmations.json`; the next
`--stage analyze` run merges confirmed duplicates and adds confirmed goals
before calculating scores.
The JSON report keeps evidence and confidence for goals, assists, scores,
lineups, captains, and time findings. It marks whether each goal is confirmed
by both Meczyk/R recordings; low-quality pairs remain single-source findings.
If a later audio statement corrects an initial goal call to an own goal, the
report preserves both the initial scorer and the correction as `own_goal`
evidence. Recorder files can also carry a user-confirmed `recorded_by` identity
when the operator is known.
An eight-goal 5:3 result is inferred only when the full large-v3 context check
confirms the session rule to five goals. Missing captains and ambiguous names
remain unresolved rather than being inferred.

Run tests:

```sh
bin/rails spec
```

New behavior should include RSpec coverage. Prefer FactoryBot for persisted records and verified doubles, such as `instance_double`, for isolated collaborators.

Run security checks:

```sh
bin/brakeman
bin/bundler-audit
```

`bin/bundler-audit` refreshes the local advisory database before scanning, matching the clean GitHub Actions runner behavior.

Run the Rails style checker:

```sh
bin/rubocop
```

Before creating or publishing a PR, run:

```sh
bin/rails spec
bin/rubocop
bin/brakeman
```

Show framework and runtime versions:

```sh
bin/rails about
```

Synchronize the development SQLite database to the dedicated `with_db` branch:

```sh
bin/sync-production-db
```

The command requires a clean working tree, fetches `main` and `with_db`, rebases
`with_db` onto the current remote `main`, creates and verifies an online SQLite
backup, and commits `storage/production.sqlite3`. To replace the previous
database-only commit instead, run `bin/sync-production-db --amend`. The command
prints the appropriate push command but does not push automatically.

## Git Ignore Policy

The repository ignores local macOS files, editor state, Bundler local config, logs, temporary files, local SQLite databases, runtime storage, generated assets, and Rails credentials master keys.

Do not commit:

- `config/master.key`
- `.env*` files
- `storage/*` runtime files
- `tmp/*` cache/runtime files
- `log/*` logs

The tracked `storage/production.sqlite3` snapshot on the dedicated `with_db`
branch is the sole exception to the storage rule.
