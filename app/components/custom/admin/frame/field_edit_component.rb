class Admin::Frame::FieldEditComponent < ViewComponent::Base
  def initialize(field_name:)
    @field_name = field_name
  end
end
