module DeficiencyReportAiCategorization
  extend ActiveSupport::Concern

  private

    # Runs before validation because the category is mandatory and the forms do not require one while
    # AI categorization is on. Deliberately synchronous: the responsible officer is derived from the
    # category right after save and notified immediately, so classifying afterwards in a job would
    # mail the wrong department first and re-route them silently.
    def categorize_with_ai(deficiency_report)
      return unless DeficiencyReports::AiCategorizationService.enabled?
      return if deficiency_report.deficiency_report_category_id.present?

      result = DeficiencyReports::AiCategorizationService.call(deficiency_report)

      deficiency_report.category = result.category
      deficiency_report.subcategory = result.subcategory

      result
    end
end
