class ResourcePage::BannerComponent < ApplicationComponent
  renders_one :links_section
  attr_reader :resource

  def initialize(resource: )
    @resource = resource
  end

  def resource_class
    "-#{@resource.class.name.downcase}"
  end

  def banner_inline_style
    helpers.sentiment_color_style(@resource.sentiment)
  end
end
