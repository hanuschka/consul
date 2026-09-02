class Kern::Form::ImageComponent < ApplicationComponent
  def initialize(form:, attribute:, auto_submit: false, show_actions: true, crop: false,
                 crop_aspect_ratio: nil, disabled: false)
    @form = form
    @attribute = attribute
    @auto_submit = auto_submit
    @disabled = disabled
    @show_actions = show_actions
    @crop = crop
    @crop_aspect_ratio = crop_aspect_ratio
  end

  private

    def show_actions?
      @show_actions && !@disabled
    end

    def root_controllers
      return "kern--form--image shared--image-cropper" if @crop

      "kern--form--image"
    end

    def root_data
      data = {
        controller: root_controllers,
        kern__form__image_auto_submit_value: @auto_submit
      }

      if @crop
        data[:shared__image_cropper_aspect_ratio_value] = @crop_aspect_ratio
        data[:action] = "shared--image-cropper:cropped->kern--form--image#change"
      end

      data
    end

    def input_data
      data = { kern__form__image_target: "input" }

      if @crop
        data[:shared__image_cropper_target] = "input"
        data[:action] = "change->shared--image-cropper#cropOnSelect"
      else
        data[:action] = "change->kern--form--image#change"
      end

      data
    end

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
