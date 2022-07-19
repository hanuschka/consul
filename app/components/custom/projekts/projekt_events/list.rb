# frozen_string_literal: true

class Projekts::ProjektEvents::List < ApplicationComponent
  attr_reader :projekt_events

  def initialize(projekt_events:)
    @projekt_events = projekt_events
  end
end
