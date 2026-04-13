class Kern::Form::ImageableImageComponent < ApplicationComponent
  def initialize(form:, auto_submit: false, show_actions: true)
    @form = form
    @auto_submit = auto_submit
    @show_actions = show_actions
  end

  private

    def imageable
      @form.object
    end

    def image
      imageable.image || imageable.build_image
    end
end
