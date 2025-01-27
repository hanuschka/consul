class Custom::Admin::ImageFieldComponent < ApplicationComponent
  def initialize(form:, label:, required: false)
    @form = form
    @required = required
    @label = label
  end
end
