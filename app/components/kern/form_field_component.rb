class Kern::FormFieldComponent < ApplicationComponent
  def initialize(label: nil, hint: nil, divider: true, inline: false)
    @label = label
    @hint = hint
    @divider = divider
    @inline = inline
  end

  attr_reader :label, :hint, :divider, :inline
end
