class Kern::FormFieldComponent < ApplicationComponent
  def initialize(label: nil, hint: nil, divider: true, inline: false, stacked: false, required: false, form: nil, attribute: nil)
    @label = label
    @hint = hint
    @divider = divider
    @inline = inline
    @stacked = stacked
    @required = required
    @form = form
    @attribute = attribute
  end

  attr_reader :hint, :divider, :inline, :stacked, :form, :attribute

  def label
    @required && @label ? "#{@label} *" : @label
  end

  def label_for
    form.field_id(attribute) if form && attribute
  end

  def title_tag(classes)
    if label_for
      content_tag(:label, label, class: "#{classes} d-block", for: label_for)
    else
      content_tag(:div, label, class: classes)
    end
  end
end
