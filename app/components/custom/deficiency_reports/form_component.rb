class DeficiencyReports::FormComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper
  attr_reader :deficiency_report
  delegate :current_user, :ck_editor_class, to: :helpers

  def initialize(deficiency_report)
    @deficiency_report = deficiency_report
  end

    def categories
      Tag.category.order(:name)
    end

    def ai_categorization?
      DeficiencyReports::AiCategorizationService.enabled?
    end

    def intake_channel_field?
      Setting["deficiency_reports.intake_channel_required_for_on_behalf_of"].present? &&
        intake_channels.any?
    end

    def intake_channels
      @intake_channels ||= DeficiencyReport::IntakeChannel.all
    end
end
