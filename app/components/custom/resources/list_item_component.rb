# frozen_string_literal: true

class Resources::ListItemComponent < ApplicationComponent
  IMAGE_THUMB_SIZE = [300, 180].freeze
  IMAGE_THUMB_SIZE_2X = [600, 360].freeze

  renders_one :header
  renders_one :image_overlay_item
  renders_many :additional_body_sections
  renders_many :footer_sections

  def initialize(
    title:,
    description:,
    resource: nil,
    projekt: nil,
    image: nil,
    subline: nil,
    url: nil,
    url_target: nil,
    tags: [],
    image_placeholder_icon_class: "fa-file",
    header_style: nil,
    narrow_header: false,
    date: nil,
    no_footer_bottom_padding: false
  )
    @title = title
    @projekt = projekt
    @description = description
    @resource = resource
    @image = image
    @url = url
    @url_target = url_target
    @subline = subline
    @tags = tags
    @image_placeholder_icon_class = image_placeholder_icon_class
    @header_style = header_style
    @narrow_header = narrow_header
    @date = date
    @no_footer_bottom_padding = no_footer_bottom_padding
  end

  def component_class_name
    class_name = "#{@resource.class.name&.underscore}-list-item"

    class_name += " -wide" if @wide
    class_name += " -no-header" if header.blank?
    class_name += " -no-image" unless show_image?

    class_name
  end

  def days_left
    if @end_date.present?
      "Noch #{(@end_date - Date.today).to_i} Tage"
    end
  end

  def date
    return if @date.blank?

    l(@date, format: :date_only)
  end

  def truncate_length
    if @wide
      150
    else
      120
    end
  end

  def header_class
    if @narrow_header
      "-narrow"
    end
  end

  def show_author_name?
    return false if @resource.try(:submitted_anonymously?)

    @resource.is_a?(Debate) ||
      @resource.is_a?(Proposal) ||
      @resource.is_a?(Budget::Investment) ||
      @resource.is_a?(DeficiencyReport) ||
      @resource.is_a?(Topic) ||
      @resource.is_a?(Idea)
  end

  def on_behalf_of?
    return unless show_author_name?

    @resource.on_behalf_of.present?
  end

  def show_image?
    if (@resource.is_a?(Debate) || @resource.is_a?(Proposal) || @resource.is_a?(Budget::Investment)) && @resource.projekt_phase.present?
      @resource.projekt_phase.feature?("form.allow_attached_image")
    else
      @resource.respond_to?(:image)
    end
  end

  private

    def image_url
      image_variant(IMAGE_THUMB_SIZE)
    end

    def image_url_2x
      image_variant(IMAGE_THUMB_SIZE_2X)
    end

    def image_variant(size)
      return if @image.blank?

      @image.attachment&.variant(
        coalesce: true,
        resize_to_fill: size,
        saver: { quality: 85 },
        format: "jpeg"
      )
    end
end
