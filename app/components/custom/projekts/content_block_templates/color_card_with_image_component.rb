class Projekts::ContentBlockTemplates::ColorCardWithImageComponent < ApplicationComponent
  def initialize(image_url: nil)
    @image_url = image_url
  end
end
