class IdeaManagement::SettingsController < IdeaManagement::BaseController
  def index
    @settings = Setting.all.group_by(&:type)['ideas']
  end
end
