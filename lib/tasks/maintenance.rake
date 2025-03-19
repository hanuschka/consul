namespace :maintenance do
  desc "Reverify users"
  task reverify_users: :environment do
    ApplicationLogger.new.info "Reverifying users"
    VerificationServices::UsersReverifier.call
  end
end
