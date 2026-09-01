require_dependency Rails.root.join("app", "models", "site_customization", "image").to_s

SiteCustomization::Image.class_eval do
  after_save { Current.site_customization_images = nil }
  after_destroy { Current.site_customization_images = nil }

  # The whole table is a dozen rows of site chrome read many times per render,
  # so it is loaded once per request with attachments and blobs attached.
  def self.images_by_name
    Current.site_customization_images ||= with_attached_image.index_by(&:name)
  end

  def self.by_name(image_name)
    images_by_name[image_name.to_s]
  end

  def self.image_for(filename)
    by_name(filename.split(".").first)&.persisted_image
  end
end
