class MoveLandingPageMainImage < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      UPDATE active_storage_attachments AS asa
      SET record_type = 'SiteCustomization::Page',
          record_id = i.imageable_id,
          name = 'landing_desktop_header_image'
      FROM images AS i
      JOIN site_customization_pages AS p
        ON p.id = i.imageable_id
      WHERE asa.record_type = 'Image'
        AND asa.name = 'attachment'
        AND asa.record_id = i.id
        AND i.imageable_type = 'SiteCustomization::Page'
        AND p.landing = TRUE;
    SQL
  end

  def down
  end
end
