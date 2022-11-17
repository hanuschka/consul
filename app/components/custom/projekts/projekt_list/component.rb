class Projekts::ProjektList::Component < ApplicationComponent
  renders_one :body

  def initialize(projekts:, title:, wide: false)
    @projekts = projekts
    @title = title
    @wide = wide
  end

  def class_names
    if @wide
      "-wide"
    end
  end
end
