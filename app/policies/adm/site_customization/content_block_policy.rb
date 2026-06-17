class Adm::SiteCustomization::ContentBlockPolicy < ApplicationPolicy
  def update?
    return false unless @user
    return true if @user.administrator?

    @user.deficiency_report_manager? && deficiency_report_email_footer?
  end

  private

    def deficiency_report_email_footer?
      @record.respond_to?(:key) &&
        @record.key == MailerFooterHelper::DEFICIENCY_REPORT_EMAIL_FOOTER_BLOCK
    end
end
