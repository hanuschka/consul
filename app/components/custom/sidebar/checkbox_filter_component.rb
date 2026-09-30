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

    def hint_id
      "#{@id_prefix}_hint"
    end
end
