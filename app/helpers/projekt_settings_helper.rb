module ProjektSettingsHelper
  # def projekt_feature?(projekt, feature)
  #   setting = ProjektSetting.find_by(projekt: projekt, key: "projekt_feature.#{feature}")
  #   (setting && (setting.value == 'active' || setting.value == 't'  )) ? true : false
  # end
  def projekt_feature?(projekt, feature)
    setting = projekt.projekt_settings.select { |setting|
      setting.key == "projekt_feature.#{feature}"
    }.first
    (setting && (setting.value == 'active' || setting.value == 't'  )) ? true : false
  end

  def projekt_option(projekt, option)
    setting = projekt.projekt_settings.select { |setting|
      setting.key == "projekt_option.#{option}"
    }.first
    setting.value
  end

  # def projekt_option(projekt, option)
  #   ProjektSetting.find_by(projekt: projekt, key: "projekt_option.#{option}").value
  # end
end
