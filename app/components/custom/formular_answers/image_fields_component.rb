class FormularAnswers::ImageFieldsComponent < ApplicationComponent
  attr_reader :f, :formular_answer, :formular_field
  delegate :render_image, to: :helpers

  def initialize(f:, formular_field:, formular_answer:)
    @f = f
    @formular_field = formular_field
    @formular_answer = formular_answer
  end

  private

    def formular_answer_image
      formular_answer.formular_answer_images.find { |im| im.formular_field_key == formular_field.key } || f.object
    end

    def destroy_link(formular_answer_image)
      if !formular_answer_image.persisted? && formular_answer_image.cached_attachment.present?
        link_to t("images.form.delete_button"), "#", class: "delete remove-cached-attachment"
      else
        link_to_remove_association remove_association_text, f, class: "delete remove-image"
      end
    end

    def file_field(formular_answer_image)
      klass = formular_answer_image.persisted? || formular_answer_image.cached_attachment.present? ? " hide" : ""
      f.file_field :attachment,
        label_options: { class: "button hollow #{klass}" },
        accept: accepted_content_types_extensions,
        class: "js-image-attachment",
        data: { url: direct_upload_path }
    end

    def direct_upload_path
      formular_answer_image_direct_uploads_path(
        "direct_upload[formular_answer_id]": formular_answer.id,
        "direct_upload[formular_field_key]": formular_field.key
      )
    end

    def accepted_content_types_extensions
      ".jpg,.jpeg,.png"
    end

    def remove_association_text
      t("images.form.delete_button")
    end
end
