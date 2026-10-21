namespace :images do
  desc "Strip metadata from stored images, keeping orientation and colour profile. Safe to stop and re-run."
  task strip_metadata: :environment do
    report = Images::StripStoredMetadataService.call do |progress, done, total|
      puts "#{done}/#{total}: #{progress.to_h}"
    end

    puts "Image metadata: #{report.to_h}"
  end
end
