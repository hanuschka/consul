# frozen_string_literal: true

class Ideas::ListItemComponent < ApplicationComponent
  attr_reader :idea

  def initialize(idea:)
    @idea = idea
  end

  def component_attributes
    {
      resource: idea,
      title: idea.title,
      description: idea.description,
      url: helpers.idea_path(idea),
      image_url: idea.image&.variant(:card_thumb),
      image_placeholder_icon_class: "fa-lightbulb",
      subline: subline
    }
  end

  def subline
    "subline"
  end
end
