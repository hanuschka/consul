class Projekts::ContentBlockTemplates::ExternalVideoPlayerComponent < ApplicationComponent
  def initialize(url:, width: nil, height: nil)
    @url = url
    @width = width
    @height = height
  end
end
