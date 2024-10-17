# frozen_string_literal: true

class Shared::ResourceImageComponent < ApplicationComponent
  delegate :show_image_thumbnail?, to: :helpers

  def initialize(image_url:, resource:, image_placeholder_icon_class:)
    @image_url = image_url
    @resource = resource
    @image_placeholder_icon_class = image_placeholder_icon_class
  end

  def alt_text
    return "" unless @resource.respond_to?(:title)

    @resource.class.model_name.human + ": " + @resource.title
  end
end
