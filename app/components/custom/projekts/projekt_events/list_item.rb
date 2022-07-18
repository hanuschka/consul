# frozen_string_literal: true

class Projekts::ProjektEvents::ListItem < ApplicationComponent
  attr_reader :projekt_event

  def initialize(projekt_event:)
    @projekt_event = projekt_event
  end
end
