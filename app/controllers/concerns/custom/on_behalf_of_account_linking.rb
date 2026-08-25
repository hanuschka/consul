module OnBehalfOfAccountLinking
  extend ActiveSupport::Concern

  private

    # Call between validating the resource and saving it: the resource has to be sound before an
    # account is opened for it, and the account has to exist before the resource can be attributed
    # to it. Returns false only when the email could not be resolved, in which case the error sits
    # on the resource and the caller must not save.
    def link_on_behalf_of_account(resource)
      return true if resource.on_behalf_of_email.blank?

      unless on_behalf_of_account_allowed?(resource)
        report_rejected_on_behalf_of_account(resource)
        return true
      end

      result = Users::OnBehalfOfAccountService.call(
        email: resource.on_behalf_of_email,
        company_name: resource.on_behalf_of_company_name,
        name: resource.on_behalf_of
      )

      if result.success?
        resource.author = result.user
        true
      else
        resource.errors.add(:on_behalf_of_email, on_behalf_of_account_error(result.error))
        false
      end
    end

    def on_behalf_of_account_allowed?(resource)
      helpers.allowed_to_post_on_behalf_of?(current_user, resource)
    end

    # An email can only reach a create action that refuses it if the form offered an input the
    # permission denies, which means a form gate and this gate have drifted apart. The submission
    # still goes through — attributed to the submitter — but somebody typed an address that is now
    # being dropped, and that is worth hearing about rather than discovering from a puzzled officer.
    def report_rejected_on_behalf_of_account(resource)
      return if !defined?(Sentry)

      Sentry.capture_message(
        "On behalf of account rejected: form offered the input but the permission denies it",
        level: :warning,
        extra: {
          resource_class: resource.class.name,
          user_id: current_user&.id,
          controller: "#{params[:controller]}##{params[:action]}"
        }
      )
    end

    def on_behalf_of_account_error(error)
      return error unless error.is_a?(Symbol)

      t("custom.on_behalf_of_account.errors.#{error}")
    end
end
