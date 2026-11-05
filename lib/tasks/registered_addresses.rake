namespace :registered_addresses do
  desc "Asks for each user whose registered address does not match the typed address whether to relink it"
  task rematch: :environment do
    describe_address = ->(address) do
      next "none" if address.nil?

      "#{address.formatted_name}, #{address.registered_address_street.plz} " \
        "#{address.registered_address_city.name} (##{address.id})"
    end

    drifted = User.active.includes(registered_address: [:registered_address_street, :registered_address_city])
      .find_each.filter_map do |user|
      matched_id = RegisteredAddressServices::Matcher.call(
        street_address: "#{user.street_name} #{user.street_number}#{user.street_number_extension}",
        plz: user.plz,
        city_name: user.city_name
      )[:registered_address_id]

      [user, matched_id] unless matched_id == user.registered_address_id
    end

    puts "Drifted users: #{drifted.size}"
    applied = 0
    skipped = 0

    drifted.each.with_index(1) do |(user, matched_id), position|
      matched_address = RegisteredAddress.includes(:registered_address_street, :registered_address_city)
                                         .find_by(id: matched_id)

      puts
      puts "User ##{user.id} #{user.email}"
      puts "  Typed:   #{user.street_name} #{user.street_number}#{user.street_number_extension}, " \
           "#{user.plz} #{user.city_name}"
      puts "  Linked:  #{describe_address.call(user.registered_address)}"
      puts "  New:     #{describe_address.call(matched_address)}"

      answer = nil
      until %w[y n q].include?(answer)
        print "#{position}/#{drifted.size} Apply? [y/n/q] "
        input = $stdin.gets
        answer = input.nil? ? "q" : input.strip.downcase
      end

      break if answer == "q"

      if answer == "y"
        user.registered_address_id = matched_id
        user.audit_comment = "registered_addresses:rematch"
        user.save!(validate: false)
        applied += 1
      else
        skipped += 1
      end
    end

    puts
    puts "Applied: #{applied}, skipped: #{skipped}"
  end
end
