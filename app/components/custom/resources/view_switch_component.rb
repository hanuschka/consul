# frozen_string_literal: true

class Resources::ViewSwitchComponent < ApplicationComponent
  attr_reader :options, :current, :label, :param

  def initialize(options:, current:, label:, param: "view")
    @options = options
    @current = current.to_s
    @label = label
    @param = param
  end

  def current?(mode)
    mode.to_s == current
  end

  def switch_path(mode)
    query = request.query_parameters.except("page").merge(param => mode.to_s).to_query
    "#{request.path}?#{query}"
  end
end
