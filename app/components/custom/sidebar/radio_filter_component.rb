# frozen_string_literal: true

class Sidebar::RadioFilterComponent < ApplicationComponent
  def initialize(identifier:, options: [], title: "Filter", icon: "filter")
    @identifier = identifier
    @options = options
    @title = title
    @icon = icon
  end

  private

    def selection
      params[@identifier.to_s] || "all"
    end
end
