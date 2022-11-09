class Shared::Projekts::ProjektCardList::Component < ApplicationComponent
  def initialize(projekts:, title:, wide: false)
    @projekts = projekts
    @title = title
    @wide = wide
  end
end
