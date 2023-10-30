# frozen_string_literal: true

class Shared::ResourceImageComponent < ApplicationComponent
  def initialize(image_url:, resource:, image_placeholder_icon_class:)
    @image_url = image_url
    @resource = resource
    @image_placeholder_icon_class = image_placeholder_icon_class
  end

  def resource_name
    if @resource.respond_to?(:projekt_phase)
      @resource.projekt_phase.title
    else
      @resource.model_name.human
    end
  end
end