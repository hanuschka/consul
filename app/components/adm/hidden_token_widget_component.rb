class Adm::HiddenTokenWidgetComponent < ApplicationComponent
  def initialize(token:)
    @token = token
  end
end
