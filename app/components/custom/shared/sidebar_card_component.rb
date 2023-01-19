class Shared::SidebarCardComponent < ApplicationComponent
  renders_one :body
  renders_one :additional_body

  def initialize(title: nil, icon_name: "info")
    @title = title
    @icon_name = icon_name
  end
end
