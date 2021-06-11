require_dependency Rails.root.join("app", "controllers", "admin", "settings_controller").to_s

class Admin::SettingsController < Admin::BaseController
  def index
    all_settings = Setting.all.group_by(&:type)
    @configuration_settings = all_settings["configuration"]
    @feature_settings = all_settings["feature"]
    @extended_feature_settings = all_settings["extended_feature"]
    @extended_option_settings = all_settings["extended_option"]
    @participation_processes_settings = all_settings["process"]
    @map_configuration_settings = all_settings["map"]
    @proposals_settings = all_settings["proposals"]
    @remote_census_general_settings = all_settings["remote_census.general"]
    @remote_census_request_settings = all_settings["remote_census.request"]
    @remote_census_response_settings = all_settings["remote_census.response"]
    @uploads_settings = all_settings["uploads"]
    @sdg_settings = all_settings["sdg"]
  end

  def update_map
    Setting["map.latitude"] = params[:latitude].to_f
    Setting["map.longitude"] = params[:longitude].to_f
    Setting["map.zoom"] = params[:zoom].to_i
    redirect_to request_referer, notice: t("admin.settings.index.map.flash.update")
  end

  private
    def request_referer
      return request.referer + params[:setting][:tab] if params[:setting] && params[:setting][:tab]
      return request.referer + params[:tab] if params[:tab]

      request.referer
    end
end
