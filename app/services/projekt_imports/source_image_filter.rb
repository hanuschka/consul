# Which of a document's images the import will use at all, and which of those can
# additionally serve as the projekt's title image.
module ProjektImports::SourceImageFilter
  # Pixel dimensions are the honest measure of "is this a content image or a
  # letterhead fragment", and by this point every image has them — the archive
  # formats are measured with ImageMagick and the PDF path reads them out of the
  # object listing.
  def self.usable(images)
    images.select do |image|
      next false if ::AdminImage::ALLOWED_CONTENT_TYPES.exclude?(image[:content_type])

      image[:width].to_i >= ::DocumentImageExtractor::MIN_IMAGE_DIMENSION &&
        image[:height].to_i >= ::DocumentImageExtractor::MIN_IMAGE_DIMENSION
    end
  end

  # The title image is an ::Image, which accepts only the types the instance's
  # upload settings list — a narrower set than the content block gallery accepts,
  # so an AVIF has to stay a content block image.
  #
  # Content type is the only bar. ::Image::MIN_IMAGE_HEIGHT deliberately is not
  # one: Image#validate_image_dimensions returns early for a
  # SiteCustomization::Page, which is what a projekt's page is, so the height rule
  # is never enforced on a hero. Enforcing it here would grey out a wide banner
  # that Projekts::AttachPageImageService saves without complaint, and leave a
  # document whose only picture is a banner with no title image at all.
  def self.hero_content_type?(image)
    ::Image.accepted_content_types.include?(image[:content_type])
  end
end
