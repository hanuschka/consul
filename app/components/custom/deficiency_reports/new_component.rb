class DeficiencyReports::NewComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper
  include Header

  attr_reader :deficiency_report
  delegate :back_link_to, :render_custom_block, :ck_editor_class, :current_user, :auto_link_already_sanitized_html, :wysiwyg, to: :helpers

  def initialize(deficiency_report)
    @deficiency_report = deficiency_report
  end

  def title
    t("custom.deficiency_reports.new.start_new")
  end

  def districts
    @districts ||= RegisteredAddress::District.joins(:map_location).order(id: :asc)
  end

  def categories_serialized
    DeficiencyReport::Category.all.as_json(only: [:name, :id, :warning_text])
  end
end
