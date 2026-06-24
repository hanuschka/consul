# frozen_string_literal: true

class Debates::ListItemComponent < ApplicationComponent
  attr_reader :debate

  def initialize(debate:, hide_projekt_breadcrumb: false)
    @debate = debate
    @hide_projekt_breadcrumb = hide_projekt_breadcrumb
  end

  def component_attributes
    {
      resource: @debate,
      projekt: debate.projekt,
      hide_projekt_breadcrumb: @hide_projekt_breadcrumb,
      title: debate.title,
      description: debate.description,
      url: helpers.debate_path(debate)
    }
  end

  def date_formated
    l(debate.created_at, format: :date_only)
  end
end
