# Default admin user (change password after first deploy to a server!)
if Administrator.count == 0 && !Rails.env.test?
  admin = User.create!(username: "admin", email: "admin@consul.dev", password: "Aa12345678",
                       password_confirmation: "Aa12345678", confirmed_at: Time.current,
                       terms_data_storage: "1", terms_data_protection: "1", terms_general: "1")
  admin.create_administrator
end

Setting.reset_defaults

Projekt.find_or_create_by!(name: "Overview page", special_name: "projekt_overview_page", special: true)

load Rails.root.join("db", "web_sections.rb")

# Default custom pages
load Rails.root.join("db", "pages.rb")

# Sustainable Development Goals
load Rails.root.join("db", "sdg.rb")

# Default custom content blocks
load Rails.root.join("db", "content_blocks.rb")
