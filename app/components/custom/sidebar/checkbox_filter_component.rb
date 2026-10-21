# frozen_string_literal: true

class Sidebar::CheckboxFilterComponent < ApplicationComponent
  def initialize(identifier:, options:, title:, icon:, id_prefix:, empty_text: nil)
    @identifier = identifier
    @options = options
    @title = title
    @icon = icon
    @id_prefix = id_prefix
    @empty_text = empty_text
  end

  private

    def selection
      Array(params[@identifier]).map(&:to_s)
    end

    def checked?(value)
      selection.include?(value.to_s)
    end

    def option_class(option)
      class_names("selected-option": checked?(option[1]), "u-flex u-align-center gap-10": option[2])
    end

    def hint_id
      "#{@id_prefix}_hint"
    end
end
