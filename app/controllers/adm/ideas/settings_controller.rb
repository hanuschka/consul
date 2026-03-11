class Adm::Ideas::SettingsController < Adm::Ideas::BaseController
  def index
    @settings = policy_scope(Setting, policy_scope_class: Adm::Ideas::SettingPolicy::Scope)
                  .group_by(&:type)["ideas"]
  end
end
