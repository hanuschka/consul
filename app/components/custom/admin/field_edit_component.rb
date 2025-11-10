class Admin::FieldEditComponent < ViewComponent::Base
  def initialize(field_name:, allow_br_tags: false)
    @field_name = field_name
    @allow_br_tags = allow_br_tags
  end
end
