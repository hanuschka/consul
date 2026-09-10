# A projekt page is always published since SiteCustomization::Page forces the
# state on save; rows unpublished through the old admin before that stay draft
# until someone saves them, hiding the projekt while every visible setting says
# it is public. Landing and footer pages keep their own state.
class PublishAllProjektPages < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_customization_pages
      SET status = 'published',
          published_at = COALESCE(published_at, NOW())
      WHERE projekt_id IS NOT NULL
        AND landing = FALSE
        AND status <> 'published'
    SQL
  end

  def down; end
end
