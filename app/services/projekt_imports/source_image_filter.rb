# The one place that decides which of a document's images the import will use,
# and which of them becomes the title image. Shared because the analysis stage
# tells the model how many images it will get and the submit stage places them:
# if the two stages disagreed, the model would reserve a slot for an image that
# never arrives, or leave none for one that does.
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

  # Document order, because the author put the image that represents the project
  # near the top — but only among images that can actually become a title image,
  # which skips both the letterhead a municipal document opens with and the wide
  # banner strip that ::Image would reject for being too short.
  #
  # Nothing is returned when no image qualifies. Falling back to the tallest of
  # the rest would only produce a validation failure at attach time; the picker
  # in the chat shows those tiles disabled with the reason instead.
  def self.hero_candidate(images)
    images.find { |image| hero_eligible?(image) }
  end

  def self.hero_eligible?(image)
    hero_content_type?(image) && image[:height].to_i >= ::Image::MIN_IMAGE_HEIGHT
  end

  # The title image is an ::Image, which accepts only the types the instance's
  # upload settings list — a narrower set than the content block gallery accepts,
  # so an AVIF has to stay a content block image.
  def self.hero_content_type?(image)
    ::Image.accepted_content_types.include?(image[:content_type])
  end
end
