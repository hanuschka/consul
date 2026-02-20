class Kern::Form::ImageComponent < ApplicationComponent
  def initialize(form:, attribute:, auto_submit: false)
    @form = form
    @attribute = attribute
    @auto_submit = auto_submit
  end

  private

    def show_preview?
      @form.object.send(@attribute).attached? && image_errors.empty?
    end

    def preview_attachment
      @form.object.send(@attribute)
    end

    def image_errors
      @form.object.errors[@attribute].to_a
    end
end
