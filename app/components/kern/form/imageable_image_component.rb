class Kern::Form::ImageableImageComponent < ApplicationComponent
  def initialize(form:, auto_submit: false)
    @form = form
    @auto_submit = auto_submit
  end

  private

    def imageable
      @form.object
    end

    def image
      imageable.image || imageable.build_image
    end
end
