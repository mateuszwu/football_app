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
per-match rosters, player changes, goals, assists, scores, and finished-match performance
data in one transaction.

For a player who changes teams or leaves the pitch during a match, add `player_changes`
to the relevant match. `from_team` may be omitted for a player entering from the bench;
`to_team` may be omitted when the player leaves the pitch:

```json
{
  "player_changes": [
    {
      "player": "adam",
      "from_team": "Team A",
      "to_team": "Team B",
      "occurred_at": "2026-06-19 19:10"
    },
    {
      "player": "jan",
      "from_team": "Team A",
      "to_team": null,
      "occurred_at": "2026-06-19 19:20"
    }
  ]
}
```

Changes are applied chronologically before goals are imported. This allows the same
player to score or assist for either team at the relevant moment. Match Elo uses the
player's final team; a player who finishes off the pitch is excluded from both teams'
Elo rosters.

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

### Match audio workflow

Run the workflow for a date using recordings in `~/Downloads`:

```sh
python3 script/match_transcription_workflow.py --date 2026-09-20
```

It selects `Meczyk-*` audio by the date in the filename and matching `6aa*.json`
Suunto GPS logs by their `DeviceLog` date. It reads the active approved player
roster through Rails, decodes audio to neutral PCM without denoising, and runs
the full local `ggml-large-v3.bin` model. Results go to
`tmp/match_transcription_workflow/YYYY-MM-DD`.

The workflow scans timestamped transcript segments against the roster and
writes TOP 3 fuzzy/phonetic player candidates, including the raw phrase,
segment position, timestamp, component scores, and ambiguity margin, to
`analysis/player_match_candidates.json`. These candidates are evidence for the
analysis model, not automatic name replacements. The workflow then writes an
AI prompt and, by default, starts a Codex analysis task with `gpt-5.6-sol` and
`xhigh` reasoning. If Metal cannot allocate the full model, it retries the
same model on CPU; pass `--cpu` to select CPU from the start.

Use `--skip-analysis-thread` to collect, transcribe, and write the prompt
without starting Codex. The AI contract is documented in
`script/match_analysis_instructions.md` and enforced by
`script/match_analysis_output.schema.json`. If an app-native Codex task returns
the JSON outside the terminal process, pass it back with
`--analysis-result PATH` to generate the same report and review clips.
Review clips are exported as 16 kHz mono MP3 files and embedded in
`report.md` with Codex-compatible audio players.

The Markdown event-table layout is stored in
`script/templates/match_events_table.md` and used by the report renderer. For
every `gol` and `samobój`, the report adds a first table column with one of
`GPS + transkrypcja`, `GPS bez transkrypcji`, or `Transkrypcja bez GPS`. Each
goal also gets a 45-second MP3 clip embedded inline in the table, starting
5 seconds before the matching transcription mention when audio confirms the
goal. GPS is used only for a goal without an audio confirmation. Existing
review clips are removed and recreated on every completed run.

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
