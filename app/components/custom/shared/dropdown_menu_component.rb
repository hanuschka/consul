class Shared::DropdownMenuComponent < ApplicationComponent
  def initialize(name:, options:, item_css_class: nil)
    @name = name
    @options = options
    @item_css_class = item_css_class
  end
end
