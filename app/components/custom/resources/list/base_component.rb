# frozen_string_literal: true

class Resources::List::BaseComponent < ApplicationComponent
  renders_one :toolbar, Resources::List::ToolbarComponent
  renders_one :items
  renders_one :footer

  def initialize(title: nil, empty_text: nil)
    @title = title
    @empty_text = empty_text
  end

  def wide?
    helpers.cookies["wide_resources"] == "true"
  end

  def class_names
    wide? ? "-wide" : ""
  end
end
