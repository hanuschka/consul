class Adm::Form::ImageComponent < ApplicationComponent
  def initialize(form:)
    @form = form
  end

  private

    def image
      @form.object.image || @form.object.build_image
    end

    def attached?
      image.attachment.attached?
    end

    def image_errors
      image.errors[:attachment].to_a
    end
end
