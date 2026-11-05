# Coder for a jsonb column that `store` writes YAML documents into. Rows saved
# through the store hold a YAML string, rows written as plain JSON hold an
# object. Rails 7.0's YAML coder passed such objects through; from Rails 7.1 it
# hands them to the YAML parser, which raises.
class YamlInJsonbCoder
  def initialize(attr_name)
    @yaml_coder = ActiveRecord::Coders::YAMLColumn.new(attr_name)
  end

  def load(payload)
    return payload if !payload.is_a?(String) || !payload.start_with?("---")

    @yaml_coder.load(payload)
  end

  def dump(object)
    @yaml_coder.dump(object)
  end
end
