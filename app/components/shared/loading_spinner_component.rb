class Shared::LoadingSpinnerComponent < ApplicationComponent
  attr_reader :message, :size

  def initialize(message: nil, size: "medium")
    @message = message
    @size = size
  end

  def spinner_class
    "shared-loading-spinner shared-loading-spinner--#{size}"
  end
end
