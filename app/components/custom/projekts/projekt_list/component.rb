class Shared::ResourcesList::Component < ApplicationComponent
  renders_one :body

  def initialize(title:, wide: false)
    @title = title
    @wide = wide
  end

  def class_names
    if @wide
      "-wide"
    end
  end
end
