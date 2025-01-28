class Custom::Admin::ImageFieldComponent < ApplicationComponent
  def initialize(form:, label:, required: false, hint: nil)
    @form = form
    @required = required
    @label = label
    @hint = hint
  end
end
