class Admin::FieldEditComponent < ViewComponent::Base
  def initialize(record:, attribute:, kind:, allow_br_tags: false)
    @record = record
    @attribute = attribute.to_s
    @kind = kind.to_s
    @allow_br_tags = allow_br_tags
  end

  def field_name
    "#{@record.model_name.param_key}[#{@attribute}]"
  end

  def update_url
    helpers.adm_attribute_path(
      record_type: @record.class.base_class.name.underscore.tr("/", "-"),
      id: @record.id
    )
  end
end
