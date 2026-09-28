class Adm::HintComponent < ApplicationComponent
  attr_reader :panel_id

  def initialize
    @panel_id = "adm-hint-panel-#{SecureRandom.hex(4)}"
  end
end
