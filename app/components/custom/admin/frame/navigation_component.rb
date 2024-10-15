class Admin::Frame::NavigationComponent < ApplicationComponent
  renders_one :navigation_content

  def initialize(title: nil)
    @title = title
  end
end
