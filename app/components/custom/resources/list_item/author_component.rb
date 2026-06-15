# frozen_string_literal: true

class Resources::ListItem::AuthorComponent < ApplicationComponent
  attr_reader :resource, :author

  def initialize(resource:)
    @resource = resource
    @author = resource.author
  end

  private

    def linkable?
      !on_behalf_of? && !author.guest?
    end

    def show_avatar?
      linkable? && author.image&.variant(:popup).present?
    end

    def on_behalf_of?
      resource.on_behalf_of.present?
    end
end
