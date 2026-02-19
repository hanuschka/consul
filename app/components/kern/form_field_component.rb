class Kern::FormFieldComponent < ApplicationComponent
  def initialize(label:, hint: nil, divider: true)
    @label = label
    @hint = hint
    @divider = divider
  end

  attr_reader :label, :hint, :divider
end
