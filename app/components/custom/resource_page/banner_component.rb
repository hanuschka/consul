class ResourcePage::BannerComponent < ApplicationComponent
  renders_one :links_section
  renders_many :additional_resource_details
  attr_reader :resource

  delegate :current_user, :projekt_feature?, :projekt_phase_feature?, :format_date_range, to: :helpers

  def initialize(resource:, compact: false)
    @resource = resource
    @compact = compact
  end

  def image_url
    # resource.image&.variant(:large)
    polymorphic_path(resource.image.attachment.variant(
      resize_to_limit: [500, 500],
      saver: { quality: 80 },
      strip: true,
      format: "jpeg"
    ))
  end

  def big_image_url
    # resource.image&.variant(:large)
    polymorphic_path(resource.image.attachment.variant(
      resize_to_limit: [1750, 900],
      saver: { quality: 80 },
      strip: true,
      format: "jpeg"
    ))
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

  def date_string
    if resource.is_a?(Poll)
      format_date_range(resource.projekt_phase.start_date, resource.projekt_phase.end_date, separator: t("custom.polls.poll.date.to"))
    else
      l(resource.created_at, format: :new_date_with_year)
    end
  end

  def show_projekt_link?
    return false unless resource.respond_to?(:projekt)

    projekt_feature?(resource.projekt, "general.show_in_navigation") ||
      projekt_feature?(resource.projekt, "general.show_in_homepage")
  end
end
