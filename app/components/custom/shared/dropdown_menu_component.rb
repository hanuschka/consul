class Shared::DropdownMenuComponent < ApplicationComponent
  def initialize(name:, options:, item_class_name: nil)
    @name = name
    @options = options
    @item_class_name = item_class_name
  end
end
