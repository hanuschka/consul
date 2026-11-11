class AccessibilityReportsController < ApplicationController
  skip_authorization_check

  invisible_captcha only: [:create], honeypot: :subtitle, scope: :accessibility_report,
                    timestamp_enabled: false

  def create
    @custom_page = SiteCustomization::Page.find_by!(footer_key: "accessibility_report")
    raise ActiveRecord::RecordNotFound unless @custom_page.published? || current_user&.administrator?

    @accessibility_report = AccessibilityReport.new(accessibility_report_params)

    if @accessibility_report.valid?
      AccessibilityReportMailer.report_submitted(@accessibility_report.attributes).deliver_later
      AccessibilityReportMailer.confirmation(@accessibility_report.email, I18n.locale.to_s).deliver_later if @accessibility_report.email.present?
      redirect_to page_path(@custom_page.slug), notice: t("accessibility_reports.create.success")
    else
      @cards = @custom_page.cards
      render "pages/custom_page_new", status: :unprocessable_entity
    end
  end

  def self.local_prefixes
    [controller_path, "pages"]
  end
  private_class_method :local_prefixes

  private

    def accessibility_report_params
      params.require(:accessibility_report).permit(:location, :description, :assistive_technology, :email)
    end
end
