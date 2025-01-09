class DeficiencyReports::NewComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper
  include Header

  attr_reader :deficiency_report
  delegate :back_link_to, :render_custom_block, :ck_editor_class, :current_user, :suggest_data, :auto_link_already_sanitized_html, :wysiwyg, to: :helpers

  def initialize(deficiency_report)
    @deficiency_report = deficiency_report
  end

  def title
    t("custom.deficiency_reports.new.start_new")
  end

  def districts
    @districts ||= RegisteredAddress::District.joins(:map_location).order(id: :asc)
  end

  def map_coordinates_for_districts
    districts.map do |district|
      [district.id, [district.map_location.latitude, district.map_location.longitude]]
    end.to_h
  end
end
