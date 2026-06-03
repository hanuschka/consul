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

  def max_visible_length
    return nil unless @allow_br_tags

    MultilineSubtitleNormalizer::MAX_VISIBLE_LENGTH
  end

  def max_line_breaks
    return nil unless @allow_br_tags

    MultilineSubtitleNormalizer::MAX_LINE_BREAKS
  end
end
