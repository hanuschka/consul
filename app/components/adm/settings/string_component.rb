class Adm::Settings::StringComponent < ApplicationComponent
  def initialize(setting:, path:, updated:)
    @setting = setting
    @path = path
    @updated = updated
  end
end
