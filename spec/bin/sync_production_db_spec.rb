require "fileutils"
require "open3"
require "sqlite3"
require "tmpdir"

RSpec.describe "bin/sync-production-db" do
  let(:script_source) { File.expand_path("../../bin/sync-production-db", __dir__) }

  it "rebases with_db, copies the database, and creates a commit" do
    Dir.mktmpdir("sync-production-db-spec-") do |directory|
      @temporary_root = directory
      repository = build_repository
      add_main_change(repository)
      replace_development_data(repository, "new data")

      output, status = run_script(repository)

      expect(status).to be_success
      expect(git(repository, "branch", "--show-current")).to eq("with_db")
      expect(git_status(repository, "merge-base", "--is-ancestor", "origin/main", "HEAD")).to be_success
      expect(git(repository, "log", "-1", "--pretty=%s")).to eq(
        "chore(human-0): refresh production SQLite database"
      )
      expect(database_value(repository, "storage/production.sqlite3")).to eq("new data")
      expect(output).to include("Utworzono commit")
    end
  end

  it "amends only a database-only commit" do
    Dir.mktmpdir("sync-production-db-spec-") do |directory|
      @temporary_root = directory
      repository = build_repository
      replace_development_data(repository, "first snapshot")
      _output, first_status = run_script(repository)
      commit_count = git(repository, "rev-list", "--count", "HEAD")
      replace_development_data(repository, "amended snapshot")

      output, amended_status = run_script(repository, "--amend", "--no-fetch")

      expect(first_status).to be_success
      expect(amended_status).to be_success
      expect(git(repository, "rev-list", "--count", "HEAD")).to eq(commit_count)
      expect(database_value(repository, "storage/production.sqlite3")).to eq("amended snapshot")
      expect(output).to include("git push --force-with-lease origin with_db")
    end
  end

  it "stops before switching branches when the worktree is dirty" do
    Dir.mktmpdir("sync-production-db-spec-") do |directory|
      @temporary_root = directory
      repository = build_repository
      File.write(File.join(repository, "untracked.txt"), "local change")

      output, status = run_script(repository)

      expect(status).not_to be_success
      expect(git(repository, "branch", "--show-current")).to eq("main")
      expect(output).to include("drzewo robocze nie jest czyste")
    end
  end

  def build_repository
    remote = File.join(@temporary_root, "remote.git")
    repository = File.join(@temporary_root, "repository")
    run_command!(@temporary_root, "git", "init", "--bare", "--initial-branch=main", remote)
    run_command!(@temporary_root, "git", "init", "--initial-branch=main", repository)
    git(repository, "config", "user.email", "spec@example.com")
    git(repository, "config", "user.name", "Spec User")
    git(repository, "remote", "add", "origin", remote)

    FileUtils.mkdir_p(File.join(repository, "bin"))
    FileUtils.mkdir_p(File.join(repository, "storage"))
    FileUtils.cp(script_source, File.join(repository, "bin/sync-production-db"))
    FileUtils.chmod("u+x", File.join(repository, "bin/sync-production-db"))
    File.write(File.join(repository, ".gitignore"), "/storage/*\n")
    create_database(repository, "storage/development.sqlite3", "development")
    create_database(repository, "storage/production.sqlite3", "production")

    git(repository, "add", ".gitignore", "bin/sync-production-db")
    git(repository, "commit", "-m", "Add sync command")
    git(repository, "push", "-u", "origin", "main")
    git(repository, "switch", "-c", "with_db")
    git(repository, "add", "--force", "storage/production.sqlite3")
    git(repository, "commit", "-m", "chore(human-0): add production database")
    git(repository, "push", "-u", "origin", "with_db")
    git(repository, "switch", "main")
    repository
  end

  def add_main_change(repository)
    File.write(File.join(repository, "main-change.txt"), "new main content")
    git(repository, "add", "main-change.txt")
    git(repository, "commit", "-m", "Update main")
    git(repository, "push", "origin", "main")
  end

  def create_database(repository, relative_path, value)
    database = SQLite3::Database.new(File.join(repository, relative_path))
    database.execute("CREATE TABLE entries (value TEXT NOT NULL)")
    database.execute("INSERT INTO entries (value) VALUES (?)", value)
  ensure
    database&.close
  end

  def replace_development_data(repository, value)
    database = SQLite3::Database.new(File.join(repository, "storage/development.sqlite3"))
    database.execute("UPDATE entries SET value = ?", value)
  ensure
    database&.close
  end

  def database_value(repository, relative_path)
    database = SQLite3::Database.new(File.join(repository, relative_path))
    database.get_first_value("SELECT value FROM entries")
  ensure
    database&.close
  end

  def run_script(repository, *arguments)
    Open3.capture2e(File.join(repository, "bin/sync-production-db"), *arguments, chdir: repository)
  end

  def git(repository, *arguments)
    output, status = Open3.capture2e("git", *arguments, chdir: repository)
    raise output unless status.success?

    output.strip
  end

  def git_status(repository, *arguments)
    _output, status = Open3.capture2e("git", *arguments, chdir: repository)
    status
  end

  def run_command!(directory, *command)
    output, status = Open3.capture2e(*command, chdir: directory)
    raise output unless status.success?
  end
end
