class Kern::Form::ImageComponent < ApplicationComponent
  def initialize(form:, attribute:, auto_submit: false, show_actions: true)
    @form = form
    @attribute = attribute
    @auto_submit = auto_submit
    @show_actions = show_actions
  end

  private

    def show_preview?
      value = @form.object.send(@attribute)
      value.respond_to?(:attached?) && value.attached? && image_errors.empty?
    end

    def preview_attachment
      value = @form.object.send(@attribute)
      value.is_a?(::Image) ? value.attachment : value
    end

    def image_errors
      @form.object.errors[@attribute].to_a
    end
end
