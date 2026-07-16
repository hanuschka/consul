class AddFooterPositionToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  FOOTER_KEYS = %w[privacy additional_privacy conditions accessibility impressum
                   netiquette contact_us open_source].freeze

  def up
    add_column :site_customization_pages, :footer_position, :integer

    FOOTER_KEYS.each_with_index do |key, index|
      execute <<~SQL.squish
        UPDATE site_customization_pages
        SET footer_position = #{index + 1}
        WHERE footer_key = '#{key}'
      SQL
    end
  end

  def down
    remove_column :site_customization_pages, :footer_position
  end
end
