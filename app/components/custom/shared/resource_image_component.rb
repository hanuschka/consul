# frozen_string_literal: true

class Shared::ResourceImageComponent < ApplicationComponent
  delegate :show_image_thumbnail?, to: :helpers

  def initialize(
    image_url:, resource:, image_placeholder_icon_class:,
    image_url_2x: nil, placeholder_hint: nil, ai_generated: false,
    credits: nil
  )
    @image_url = image_url
    @image_url_2x = image_url_2x
    @resource = resource
    @image_placeholder_icon_class = image_placeholder_icon_class
    @placeholder_hint = placeholder_hint
    @ai_generated = ai_generated
    @credits = credits
  end

  def alt_text
    return "" unless @resource.respond_to?(:title)

    @resource.class.model_name.human + ": " + @resource.title
  end
end
