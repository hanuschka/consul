# frozen_string_literal: true

class Resources::List::BaseComponent < ApplicationComponent
  DEFAULT_VIEW_COOKIE = "wide_resources"

  renders_one :toolbar, ->(**options) { Resources::List::ToolbarComponent.new(wide: wide?, **options) }
  renders_one :items
  renders_one :footer

  def initialize(title: nil, empty_text: nil, view_cookie: DEFAULT_VIEW_COOKIE, wide_by_default: false)
    @title = title
    @empty_text = empty_text
    @view_cookie = view_cookie
    @wide_by_default = wide_by_default
  end

  def wide?
    value = helpers.cookies[@view_cookie]
    value.present? ? value == "true" : @wide_by_default
  end

  def page_specific_view_cookie?
    @view_cookie != DEFAULT_VIEW_COOKIE
  end

  def class_names
    wide? ? "-wide" : ""
  end
end
