module SettingHelpers
  # Setting[] reads through the Current.settings cache (app/models/custom/setting.rb), which
  # Setting[]= does not invalidate — so a value written mid-example stays invisible to the code under
  # test until the cache is dropped. Always change settings through this helper.
  def set_setting(key, value)
    Setting[key] = value
    Current.settings = nil
  end
end

RSpec.configure do |config|
  config.include SettingHelpers
end
