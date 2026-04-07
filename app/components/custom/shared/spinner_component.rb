class Shared::SpinnerComponent < ApplicationComponent
  def initialize(size: :medium)
    @size = size
  end

  def size_class
    "shared-spinner--#{@size}"
  end
end
