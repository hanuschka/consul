# frozen_string_literal: true

class Resources::List::EmptyComponent < ApplicationComponent
  def initialize(text:)
    @text = text
  end
end
