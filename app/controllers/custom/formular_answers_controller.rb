class FormularAnswersController < ApplicationController
  include ImageAttributes
  include DocumentAttributes

  respond_to :js

  skip_authorization_check only: :update, if: -> {
    skip_authorization_check_for_guesst_user_with_token?
  }


  invisible_captcha only: [:create], honeypot: :subtitle

  def create
    submitter_hash = { submitter_id: current_user&.id, original_submitter_email: current_user&.email }
    @formular_answer = FormularAnswer.new(formular_answer_params.merge(submitter_hash))
    @formular_answer.answer_errors = {}

    authorize! :create, @formular_answer

    @formular_fields = @formular_answer.formular.formular_fields.primary.each(&:set_custom_attributes)
    validate_answer(@formular_answer)

    if @formular_answer.answer_errors.none? && @formular_answer.save
      Mailer.formular_answer_confirmation(@formular_answer).deliver_later
      @success_notification = t("custom.formular_answer.notifications.success")
      render :create_success
    else
      render :create
    end
  end

  def update
    @formular_answer = FormularAnswer.find(params[:id])
    @formular_answer.answer_errors = {}

    if @formular_follow_up_letter_recipient.blank?
      authorize! :update, @formular_answer
    end

    @formular_answer.answers = @formular_answer.answers.merge(formular_answer_params["answers"].to_h)

    @formular_fields = @formular_answer.formular.formular_fields.follow_up.each(&:set_custom_attributes)
    validate_answer(@formular_answer)

    if @formular_answer.answer_errors.none? && @formular_answer.save
      @success_notification = t("custom.formular_answer.notifications.success")
      render :update_success
    else
      remder :update
    end
  end

  private

    def formular_answer_params
      params.require(:formular_answer).permit(
        :formular_id, answers: {},
        formular_answer_images_attributes: image_attributes.push(:formular_field_key),
        formular_answer_documents_attributes: document_attributes.push(:formular_field_key)
      )
    end

    def validate_answer(formular_answer)
      formular_answer.valid?

      formular_fields = formular_answer.persisted? ? formular_answer.formular_fields.follow_up : formular_answer.formular_fields.primary

      formular_fields.each do |formular_field|
        validate_for_presence(formular_answer, formular_field) if formular_field.required?
        next if formular_answer.answer_errors[formular_field.key].present?

        next if formular_answer.answers[formular_field.key].blank?

        validations = formular_field.options["validates"]
        next unless validations

        validations.keys.each do |validation|
          send("validate_for_#{validation}", formular_answer, formular_field)
        end
      end
    end

    def validate_for_presence(formular_answer, formular_field)
      if formular_field.kind == "image"
        return if formular_answer.formular_answer_images.find { |im| im.formular_field_key == formular_field.key }.present?
      else
        return if formular_answer.answers[formular_field.key].present?
      end

      error_message = t("custom.formular_answer.errors.blank")
      formular_answer.answer_errors[formular_field.key] = error_message
    end

    def validate_for_length(formular_answer, formular_field)
      rule = formular_field.options["validates"]["length"]

      if rule["minimum"] && formular_answer.answers[formular_field.key].length < rule["minimum"]
        error_message = t("custom.formular_answer.errors.length.minimum", minimum: rule["minimum"])
        formular_answer.answer_errors[formular_field.key] = error_message
      elsif rule["maximum"] && formular_answer.answers[formular_field.key].length > rule["maximum"]
        error_message = t("custom.formular_answer.errors.length.maximum", maximum: rule["maximum"])
        formular_answer.answer_errors[formular_field.key] = error_message
      end
    end

    def validate_for_format(formular_answer, formular_field)
      rule = formular_field.options["validates"]["format"]
      regexp = Regexp.new(rule)

      unless regexp.match?(formular_answer.answers[formular_field.key])
        error_message = t("custom.formular_answer.errors.format")
        formular_answer.answer_errors[formular_field.key] = error_message
      end
    end

    def skip_authorization_check_for_guesst_user_with_token?
      if params[:token].present?
        @formular_follow_up_letter_recipient = FormularFollowUpLetterRecipient.find_by(
          subscription_token: params[:token]
        )
      end

      @formular_follow_up_letter_recipient.present?
    end
end
