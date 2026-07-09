# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

if Gem.loaded_specs.key?("rspec-core")
  require "rspec/core/rake_task"

  RSpec::Core::RakeTask.new(:spec)

  namespace :spec do
    RSpec::Core::RakeTask.new(:system) do |task|
      task.pattern = "spec/system/**/*_spec.rb"
    end
  end
end
