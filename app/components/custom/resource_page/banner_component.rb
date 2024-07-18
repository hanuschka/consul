class ResourcePage::BannerComponent < ApplicationComponent
  renders_one :links_section
  attr_reader :resource

  delegate :current_user, to: :helpers

  def initialize(resource:, compact: false)
    @resource = resource
    @compact = compact
  end

  def resource_class
    base_class = "-#{@resource.class.name.split("::").last.downcase}"

    if @resource.image.present?
      base_class += " -with-image"
    end

    if @compact
      base_class += " -compact"
    end

    base_class
  end
end
