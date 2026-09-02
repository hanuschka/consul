class AddWatermarkIdentifierToImages < ActiveRecord::Migration[6.1]
  # The identifier carried inside the invisible watermark of a generated image,
  # stored so a decoded watermark can be traced back to the record it came
  # from, and so a signed provenance manifest can later reference it as a soft
  # binding. Hex rather than the raw bit string the watermarking tool takes:
  # the encoder carries 61 usable bits, which is not a byte boundary, and hex
  # keeps the column readable.
  def change
    add_column :images, :watermark_identifier, :string

    add_index :images, :watermark_identifier, unique: true,
              where: "watermark_identifier IS NOT NULL"
  end
end
