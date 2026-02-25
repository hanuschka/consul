class Kern::FormFieldComponent < ApplicationComponent
  def initialize(label: nil, hint: nil, divider: true, inline: false, required: false)
    @label = label
    @hint = hint
    @divider = divider
    @inline = inline
    @required = required
  end

  attr_reader :hint, :divider, :inline

  def label
    @required && @label ? "#{@label} *" : @label
  end
end
