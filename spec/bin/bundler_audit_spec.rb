require "rails_helper"
require "bundler/audit/cli"

RSpec.describe "bin/bundler-audit" do
  describe "default arguments" do
    context "when no arguments are provided" do
      it "updates the advisory database before checking the configured lockfile" do
        original_arguments = ARGV.dup
        ARGV.replace([])
        allow(Bundler::Audit::CLI).to receive(:start)

        load Rails.root.join("bin/bundler-audit")

        expect(ARGV).to eq(%w[check --update --config config/bundler-audit.yml])
      ensure
        ARGV.replace(original_arguments)
      end
    end

    context "when an explicit non-check command is provided" do
      it "keeps the command unchanged" do
        original_arguments = ARGV.dup
        ARGV.replace([ "update" ])
        allow(Bundler::Audit::CLI).to receive(:start)

        load Rails.root.join("bin/bundler-audit")

        expect(ARGV).to eq([ "update" ])
      ensure
        ARGV.replace(original_arguments)
      end
    end
  end
end
