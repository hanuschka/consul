class Kern::Form::VideoComponent < ApplicationComponent
  def initialize(form:, attribute:, auto_submit: false, show_actions: true, disabled: false)
    @form = form
    @attribute = attribute
    @auto_submit = auto_submit
    @disabled = disabled
    @show_actions = show_actions
  end

  private

    def show_actions?
      @show_actions && !@disabled
    end

    def show_preview?
      value = @form.object.send(@attribute)
      value.respond_to?(:attached?) && value.attached? && video_errors.empty?
    end

    def preview_attachment
      @form.object.send(@attribute)
    end

    def video_errors
      @form.object.errors[@attribute].to_a
    end
end
