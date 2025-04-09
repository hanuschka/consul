class RenameLandingPageFields < ActiveRecord::Migration[6.1]
  def change
    rename_column :site_customization_pages, :landing_site_logo_not_clickable, :landing_site_logo_follow_to_landing_page
  end
end
