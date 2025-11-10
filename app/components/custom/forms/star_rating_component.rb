class Forms::StarRatingComponent < ApplicationComponent
  def initialize(f:, attribute:, scale: 5)
    @f = f
    @attribute = attribute
    @scale = scale
  end
end
