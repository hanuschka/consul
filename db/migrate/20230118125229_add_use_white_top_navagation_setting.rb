class AddUseWhiteTopNavagationSetting < ActiveRecord::Migration[5.2]
  def change
    Setting.add_new_settings
  end
end
