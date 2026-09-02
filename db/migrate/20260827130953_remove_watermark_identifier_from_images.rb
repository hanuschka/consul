class RemoveWatermarkIdentifierFromImages < ActiveRecord::Migration[6.1]
  # The invisible watermark this column indexed is gone: its payload was a
  # random identifier no third party could resolve, so it marked nothing an
  # outside verifier could read. Generated images now carry the IPTC
  # DigitalSourceType field instead, which is self-describing and needs no
  # lookup, and therefore needs no column.
  def up
    remove_index :images, column: :watermark_identifier, if_exists: true
    remove_column :images, :watermark_identifier, if_exists: true
  end

  def down
    add_column :images, :watermark_identifier, :string

    add_index :images, :watermark_identifier, unique: true,
              where: "watermark_identifier IS NOT NULL"
  end
end
