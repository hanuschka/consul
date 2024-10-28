class Projekts::ContentBlockTemplates::SingleImageComponent < ViewComponent::Base
  def initialize(image:)
    @image = image
  end
end
