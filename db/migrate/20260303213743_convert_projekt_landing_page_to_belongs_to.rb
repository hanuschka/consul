class ConvertProjektLandingPageToBelongsTo < ActiveRecord::Migration[6.1]
  def up
    add_reference :projekts, :landing_page,
      foreign_key: { to_table: :site_customization_pages },
      index: true, null: true

    execute <<~SQL
      UPDATE projekts
      SET landing_page_id = sub.site_customization_page_id
      FROM (
        SELECT DISTINCT ON (projekt_id)
          projekt_id, site_customization_page_id
        FROM landing_pages_projekts
        ORDER BY projekt_id, site_customization_page_id ASC
      ) sub
      WHERE projekts.id = sub.projekt_id
    SQL
  end

  def down
    execute <<~SQL
      INSERT INTO landing_pages_projekts
        (site_customization_page_id, projekt_id)
      SELECT landing_page_id, id
      FROM projekts
      WHERE landing_page_id IS NOT NULL
    SQL

    remove_reference :projekts, :landing_page
  end
end
