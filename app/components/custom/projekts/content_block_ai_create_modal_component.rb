class Projekts::ContentBlockAiCreateModalComponent < ApplicationComponent
  def initialize(show_projekt_context_toggle: true)
    @show_projekt_context_toggle = show_projekt_context_toggle
  end

  def show_projekt_context_toggle?
    @show_projekt_context_toggle
  end
end
