class Admin::Frame::FieldEditComponent < ViewComponent::Base
  def initialize(field_name:, title: nil)
    @field_name = field_name
    @title = title
  end
end
