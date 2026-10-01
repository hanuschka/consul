class StripStoredImageMetadata < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    report = Images::StripStoredMetadataService.call do |progress, done, total|
      say "#{done}/#{total}: #{progress.to_h}", true
    end

    say "Image metadata: #{report.to_h}"
  end

  def down
  end
end
