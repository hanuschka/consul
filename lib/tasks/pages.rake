namespace :pages do
  desc "Creates default footer pages that don't exist yet"
  task add_default_pages: :environment do
    %w[privacy conditions accessibility impressum contact_us
       netiquette additional_privacy open_source].each do |page_file|
      load Rails.root.join("db", "pages", "#{page_file}.rb")
    end
  end
end
