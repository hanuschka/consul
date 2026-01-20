class Admin::HiddenTokenWidgetComponent < ApplicationComponent
  def initialize(token:)
    @token = token
  end
end
