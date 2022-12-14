class Shared::DropdownMenuComponent < ApplicationComponent
  def initialize(name:, options:, item_css_class: nil, selected_option: nil, link_mode: false)
    @name = name
    @options = options
    @item_css_class = item_css_class
    @selected_option = selected_option
    @link_mode = link_mode
  end
end
