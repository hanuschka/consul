# frozen_string_literal: true

class Shared::DropdownMenuComponent < ApplicationComponent
  renders_one :trigger_button
  renders_many :options

  def initialize(item_css_class: nil)
    @item_css_class = item_css_class
  end
end
