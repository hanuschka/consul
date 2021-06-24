namespace :settings do
  desc "Add new settings"
  task add_new_settings: :environment do
    ApplicationLogger.new.info "Adding new settings"
    Setting.add_new_settings
  end

  desc "Remove obsolete tasks"
  task destroy_obsolete: :environment do
    ApplicationLogger.new.info "Removing obsolete settings"
    Setting.destroy_obsolete
  end

  desc "Rename existing settings"
  task rename_setting_keys: :environment do
    ApplicationLogger.new.info "Renaming existing settings"
    Setting.rename_key from: "dashboard.emails", to: "feature.dashboard.notification_emails"
  end
end
