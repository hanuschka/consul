class AddAiGeneratedToImages < ActiveRecord::Migration[6.1]
  # Filenames the image generators pick themselves and nothing else writes.
  # `_` is a single-character wildcard in LIKE, so the literal underscores are
  # escaped. proposals.generated_image / budget_investments.generated_image are
  # deliberately not used as a source: they are set before an image is attached
  # and never cleared when one is removed, so they are true for contributions
  # whose visible image is the author's own photograph.
  #
  # "projekt_<id>_hero.jpg" is NOT in this list even though
  # ProjektImports::ExecuteImportJob used to write it: the source-document hero
  # in ProjektImports::AttachSourceImagesService names the admin's own
  # photograph identically. Generated import heroes are found through their
  # projekt_import instead.
  GENERATED_FILENAME_PATTERNS = [
    'ai\_generated\_%.jpg',
    'projekt\_%\_ai\_banner.jpg',
    'projekt\_%\_ai\_hero.jpg'
  ].freeze

  def up
    add_column :images, :ai_generated, :boolean, default: false, null: false

    GENERATED_FILENAME_PATTERNS.each do |pattern|
      execute(<<~SQL.squish)
        UPDATE images
        SET ai_generated = TRUE
        WHERE id IN (
          SELECT attachments.record_id
          FROM active_storage_attachments attachments
          INNER JOIN active_storage_blobs blobs ON blobs.id = attachments.blob_id
          WHERE attachments.record_type = 'Image'
            AND attachments.name = 'attachment'
            AND blobs.filename LIKE #{quote(pattern)} ESCAPE '\\'
        )
      SQL
    end

    # Import title images generated before the filename carried "ai": the
    # import row records that the admin chose generation over a picture from
    # the document, which the filename alone cannot distinguish.
    execute(<<~SQL.squish)
      UPDATE images
      SET ai_generated = TRUE
      WHERE imageable_type = 'SiteCustomization::Page'
        AND imageable_id IN (
          SELECT pages.id
          FROM site_customization_pages pages
          INNER JOIN projekt_imports imports ON imports.projekt_id = pages.projekt_id
          WHERE imports.title_image_mode = 'generated'
            AND imports.image_status = 'completed'
        )
    SQL
  end

  def down
    remove_column :images, :ai_generated
  end
end
