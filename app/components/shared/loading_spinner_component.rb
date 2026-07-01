class Shared::LoadingSpinnerComponent < ApplicationComponent
  attr_reader :message, :size, :vertical

  def initialize(message: nil, size: "medium", vertical: false)
    @message = message
    @size = size
    @vertical = vertical
  end

  def container_classes
    classes = ["shared-loading-spinner-container"]

    if vertical
      classes << "-vertical"
    end

    classes.join(" ")
  end

  def spinner_class
    "shared-loading-spinner shared-loading-spinner--#{size}"
  end
end
