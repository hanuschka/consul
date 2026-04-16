class Kern::Form::GalleryableImagesComponent < ApplicationComponent
  def initialize(form:)
    @form = form
  end

  private

    def imageable
      @form.object
    end

    def images
      imageable.images
    end
end
