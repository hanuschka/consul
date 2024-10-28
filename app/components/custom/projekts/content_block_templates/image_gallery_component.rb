class Projekts::ContentBlockTemplates::ImageGalleryComponent < ViewComponent::Base
  def initialize(title:, images:, template_mode: false)
    @title = title
    @images = images
    @template_mode = template_mode
  end
end
