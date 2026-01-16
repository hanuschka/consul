class Kern::FormFieldComponent < ApplicationComponent
  def initialize(label:, hint: nil)
    @label = label
    @hint = hint
  end

  attr_reader :label, :hint
end
