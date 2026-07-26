namespace :relationships do
  desc "Build missing persisted pair statistics (set FORCE=1 to rebuild every season)"
  task rebuild_pair_stats: :environment do
    scope = ENV["FORCE"] == "1" ? Season.all : Season.where(pair_stats_generated_at: nil)

    scope.find_each do |season|
      pair_count = Relationships::RebuildSeasonPairStats.call(season:)
      puts "Rebuilt #{pair_count} pair statistics for #{season.name}"
    end
  end
end
