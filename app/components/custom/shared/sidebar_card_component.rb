# frozen_string_literal: true

class Shared::SidebarCardComponent < ApplicationComponent
  renders_many :additional_sections
  renders_one :edit_link

  def initialize(
    title: nil,
    description: nil,
    icon_name: "info",
    class_name: nil,
    opened_on_mobile: false,
    heading_level: 2
  )
    @title = title
    @icon_name = icon_name
    @class_name = class_name
    @description = description
    @opened_on_mobile = opened_on_mobile
    @heading_level = heading_level
  end

  def heading_tag
    "h#{@heading_level}"
  end

  def content_id
    @content_id ||= "sidebar-card-content-#{SecureRandom.hex(4)}"
  end

  def class_name
    base_class = @class_name || ""

    if !@opened_on_mobile
      base_class += " -collapsed-on-mobile"
    end

    base_class
  end
end
