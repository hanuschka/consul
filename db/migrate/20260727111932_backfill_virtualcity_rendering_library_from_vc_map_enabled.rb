class BackfillVirtualcityRenderingLibraryFromVcMapEnabled < ActiveRecord::Migration[6.1]
  def up
    Projekt.reset_column_information
    ProjektSetting.reset_column_information
    MapLocation.reset_column_information

    Projekt.find_each do |projekt|
      setting_value = projekt.projekt_settings
        .find_by(key: "projekt_feature.general.vc_map_enabled")&.value

      next if setting_value != "active"
      next if projekt.map_location.blank?

      projekt.map_location.update!(rendering_library: "virtualcity")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
