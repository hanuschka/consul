class Shared::DropdownMenuComponent < ApplicationComponent
  renders_many :options

  def initialize(name: nil, item_css_class: nil, selected_option: nil)
    @name = name
    @item_css_class = item_css_class
    @selected_option = selected_option
  end
end
