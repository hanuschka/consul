# frozen_string_literal: true

class Debates::ListItemComponent < ApplicationComponent
  attr_reader :debate

  def initialize(debate:)
    @debate = debate
  end

  def component_attributes
    {
      resource: @debate,
      projekt: debate.projekt,
      title: debate.title,
      description: debate.description,
      url: helpers.debate_path(debate)
    }
  end

  def date_formated
    l(debate.created_at, format: :date_only)
  end
end
