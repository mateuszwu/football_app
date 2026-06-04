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

## Git Ignore Policy

The repository ignores local macOS files, editor state, Bundler local config, logs, temporary files, local SQLite databases, runtime storage, generated assets, and Rails credentials master keys.

Do not commit:

- `config/master.key`
- `.env*` files
- `storage/*` runtime files
- `tmp/*` cache/runtime files
- `log/*` logs
