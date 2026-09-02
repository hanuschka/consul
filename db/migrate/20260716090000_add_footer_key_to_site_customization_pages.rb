class AddFooterKeyToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  BACKFILL_SLUGS = %w[privacy conditions accessibility impressum contact_us netiquette].freeze

  def up
    add_column :site_customization_pages, :footer_key, :string
    add_index :site_customization_pages, :footer_key, unique: true

    # Slugs were not editable before footer_key was introduced, so the current
    # slug still identifies the seeded page on every instance.
    BACKFILL_SLUGS.each do |slug|
      execute <<~SQL.squish
        UPDATE site_customization_pages
        SET footer_key = '#{slug}'
        WHERE id = (
          SELECT MIN(id) FROM site_customization_pages
          WHERE slug = '#{slug}' AND projekt_id IS NULL
        )
      SQL
    end
  end

  def down
    remove_index :site_customization_pages, :footer_key
    remove_column :site_customization_pages, :footer_key
  end
end
