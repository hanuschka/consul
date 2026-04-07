class Kern::FormFieldComponent < ApplicationComponent
  def initialize(label: nil, hint: nil, divider: true, inline: false, stacked: false, required: false)
    @label = label
    @hint = hint
    @divider = divider
    @inline = inline
    @stacked = stacked
    @required = required
  end

  attr_reader :hint, :divider, :inline, :stacked

  def label
    @required && @label ? "#{@label} *" : @label
  end
end
