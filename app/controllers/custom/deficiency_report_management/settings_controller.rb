class DeficiencyReportManagement::SettingsController < DeficiencyReportManagement::BaseController
  def index
    @settings = Setting.all.group_by(&:type)['deficiency_reports']
  end
end
