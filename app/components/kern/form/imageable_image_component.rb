class Kern::Form::ImageableImageComponent < ApplicationComponent
  def initialize(form:, auto_submit: false, show_actions: true, crop: false, crop_aspect_ratio: nil)
    @form = form
    @auto_submit = auto_submit
    @show_actions = show_actions
    @crop = crop
    @crop_aspect_ratio = crop_aspect_ratio
  end

  private

    def imageable
      @form.object
    end

    def image
      imageable.image || imageable.build_image
    end
end
