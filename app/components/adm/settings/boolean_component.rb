class Adm::Settings::BooleanComponent < ApplicationComponent
  def initialize(setting:, path:, updated:)
    @setting = setting
    @path = path
    @updated = updated
  end
end
