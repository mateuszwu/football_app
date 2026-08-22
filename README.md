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

## Common Commands

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
