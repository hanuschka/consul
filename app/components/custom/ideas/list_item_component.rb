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
      url: helpers.idea_path(idea)
    }
  end
end
