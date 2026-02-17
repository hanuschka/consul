class Kern::Form::ImageComponent < ApplicationComponent
  def initialize(form:, label:, hint: nil)
    @form = form
    @label = label
    @hint = hint
  end

  private

    def imageable
      @form.object
    end

    def image
      imageable.image || imageable.build_image
    end

    def show_preview?
      imageable.image&.attachment&.attached? && image_errors.empty?
    end

    def image_errors
      image_record = imageable.image
      return [] unless image_record

      image_record.errors.full_messages
    end
end
