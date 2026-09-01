class AddAiGeneratedToImages < ActiveRecord::Migration[6.1]
  # Filenames the image generators pick themselves and nothing else writes.
  # `_` is a single-character wildcard in LIKE, so the literal underscores are
  # escaped -- Postgres reads a backslash as the escape character by default.
  # proposals.generated_image / budget_investments.generated_image are
  # deliberately not used as a source: they are set before an image is attached
  # and never cleared when one is removed, so they are true for contributions
  # whose visible image is the author's own photograph.
  #
  # "projekt_<id>_hero.jpg" is absent even though ProjektImports::ExecuteImportJob
  # used to write it: the source-document hero in
  # ProjektImports::AttachSourceImagesService names the admin's own photograph
  # identically. Generated import heroes are found through their projekt_import
  # instead.
  GENERATED_FILENAME_PATTERNS = [
    'ai\_generated\_%.jpg',
    'projekt\_%\_ai\_banner.jpg'
  ].freeze

  def up
    add_column :images, :ai_generated, :boolean, default: false, null: false

    execute(<<~SQL.squish)
      UPDATE images
      SET ai_generated = TRUE
      WHERE ai_generated = FALSE
        AND id IN (
          SELECT attachments.record_id
          FROM active_storage_attachments attachments
          INNER JOIN active_storage_blobs blobs ON blobs.id = attachments.blob_id
          WHERE attachments.record_type = 'Image'
            AND attachments.name = 'attachment'
            AND blobs.filename LIKE ANY (ARRAY[#{GENERATED_FILENAME_PATTERNS.map { |pattern| quote(pattern) }.join(", ")}])
        )
    SQL

    # Import title images, which the filename alone cannot tell apart from a
    # picture the admin picked out of the source document: the import row
    # records that they chose generation instead.
    execute(<<~SQL.squish)
      UPDATE images
      SET ai_generated = TRUE
      WHERE ai_generated = FALSE
        AND imageable_type = 'SiteCustomization::Page'
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
