# frozen_string_literal: true

class Resources::ListComponent < ApplicationComponent
  renders_one :toolbar, Resources::List::ToolbarComponent
  renders_one :items
  renders_one :footer

  def initialize(title: nil, empty_text: nil, aria_label: nil)
    @title = title
    @empty_text = empty_text
    @aria_label = aria_label
  end

  def wide?
    helpers.cookies["wide_resources"] == "true"
  end

  def class_names
    wide? ? "-wide" : ""
  end
end
