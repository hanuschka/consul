class Projekts::StudioEditPopupComponent < ApplicationComponent
  renders_one :extra_actions

  def initialize(popup_classes:, accept_button_class:, cancel_button_class:)
    @popup_classes = popup_classes
    @accept_button_class = accept_button_class
    @cancel_button_class = cancel_button_class
  end

  private

  attr_reader :popup_classes, :accept_button_class, :cancel_button_class
end
