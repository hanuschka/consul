namespace :offers do
  desc "Sends the reminder e-mail to providers whose reminder is due for the configured interval"
  task send_reminders: :environment do
    reminded = Offer::Provider.send_due_reminders

    puts "reminded #{reminded.size} providers"
  end
end
