class ReplaceWhiteTopNavWithHomepageNavColor < ActiveRecord::Migration[6.1]
  def up
    Setting.find_or_create_by!(key: "extended_option.general.homepage_navigation_link_color") do |setting|
      setting.value = "#000000"
    end

    Setting.where(key: "extended_feature.general.use_white_top_navigation_text").destroy_all
  end

  def down
    Setting.find_or_create_by!(key: "extended_feature.general.use_white_top_navigation_text") do |setting|
      setting.value = false
    end

    Setting.where(key: "extended_option.general.homepage_navigation_link_color").destroy_all
  end
end
