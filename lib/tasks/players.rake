namespace :players do
  desc "Assign missing player identity colors and icons"
  task assign_missing_identities: :environment do
    updated_count = 0

    Player
      .where("profile_color_key IS NULL OR profile_color_hex IS NULL OR profile_icon IS NULL")
      .find_each do |player|
        Players::AssignIdentity.call(player:)
        updated_count += 1
      end

    puts "Updated #{updated_count} players"
  end
end
