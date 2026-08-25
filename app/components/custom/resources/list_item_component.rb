# frozen_string_literal: true

class Resources::ListItemComponent < ApplicationComponent
  IMAGE_THUMB_SIZE = [300, 180].freeze
  IMAGE_THUMB_SIZE_2X = [600, 360].freeze

  renders_one :header
  renders_one :subheading
  renders_one :author, Resources::ListItem::AuthorComponent
  renders_one :image, ->(image:, resource:, image_placeholder_icon_class: "fa-file") do
    Shared::ResourceImageComponent.new(
      image_url: image_variant(image, IMAGE_THUMB_SIZE),
      image_url_2x: image_variant(image, IMAGE_THUMB_SIZE_2X),
      image_placeholder_icon_class: image_placeholder_icon_class,
      resource: resource,
      ai_generated: image&.ai_generated?
    )
  end
  renders_one :image_overlay_item
  renders_many :additional_body_sections
  renders_many :footer_sections

  def initialize(
    title:,
    description:,
    resource: nil,
    projekt: nil,
    url: nil,
    url_target: nil,
    header_style: nil,
    date: nil,
    title_heading_level: 3
  )
    @title = title
    @title_heading_level = title_heading_level
    @projekt = projekt
    @description = description
    @resource = resource
    @url = url
    @url_target = url_target

    @header_style = header_style
    @date = date
  end

  def component_class_name
    resource_name = @resource ? @resource.class.name.underscore : "resource"
    class_name = "#{resource_name}-list-item"

    class_name += " -no-header" if header.blank?
    class_name += " -no-image" if image.blank?

    class_name
  end

  def date
    return if @date.blank?

    l(@date, format: :date_only)
  end

  def show_projekt_breadcrumb?
    @projekt.present?
  end

  def show_body_heading?
    subheading? || show_projekt_breadcrumb? || date.present?
  end

  def title_text
    truncate(sanitize(@title), length: 72, escape: false)
  end

  def description_text
    formatted_description = @description&.gsub("</p><p>", "</p> <p>")

    truncate(sanitize(strip_tags(formatted_description)), length: 160, escape: false)
  end

  def title_heading_tag
    "h#{@title_heading_level}"
  end

  private

    def image_variant(image, size)
      return if image.blank?

      image.attachment&.variant(
        coalesce: true,
        resize_to_fill: size,
        saver: { quality: 85 },
        format: "jpeg"
      )
    end
end
