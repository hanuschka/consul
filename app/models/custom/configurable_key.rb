# One key/value setting row (Setting, ProjektSetting, ProjektPhaseSetting) that
# the API may write: the value type it accepts and how /adm stores that type.
class ConfigurableKey
  # Switches are stored as "active"/"", and clients of the older setting
  # endpoints send those stored forms; they are read as the booleans they are.
  STORED_SWITCH_VALUES = { "active" => true, "" => false }.freeze

  attr_reader :key, :group, :value_definition, :date_format

  def initialize(key, group:, type:, date_format: nil, ai_gated: false, **definition_options)
    @key = key
    @group = group
    @date_format = date_format
    @ai_gated = ai_gated
    @value_definition = TypedValueParser::Definition.new(type:, **definition_options)
  end

  def type
    value_definition.type
  end

  def boolean?
    type == :boolean
  end

  def ai_gated?
    @ai_gated
  end

  def options
    value_definition.options
  end

  def parse(raw_value)
    if boolean? && STORED_SWITCH_VALUES.key?(raw_value)
      TypedValueParser::Result.new(value: STORED_SWITCH_VALUES[raw_value])
    else
      TypedValueParser.parse(raw_value, value_definition)
    end
  end

  # Stored the way /adm stores it, so every reader of the setting keeps working:
  # switches as "active"/"", lists space-separated and cleared values as "".
  def to_storage(value)
    return "" if value.nil?

    case type
    when :boolean then value ? "active" : ""
    when :multi_select then value.join(" ")
    when :date then storage_date(value)
    else value.to_s
    end
  end

  def from_storage(stored_value)
    case type
    when :boolean then stored_value.present? && !%w[0 false f].include?(stored_value)
    when :integer then stored_value.presence && stored_value.to_i
    when :decimal then stored_value.presence && stored_value.to_f
    when :multi_select then stored_value.to_s.split(" ")
    when :date then stored_date(stored_value)
    else stored_value
    end
  end

  private

    def storage_date(value)
      if date_format.nil?
        value
      else
        Date.iso8601(value).strftime(date_format)
      end
    end

    def stored_date(stored_value)
      return nil if stored_value.blank?

      date =
        if date_format
          Date.strptime(stored_value, date_format)
        else
          Date.iso8601(stored_value)
        end

      date.iso8601
    rescue Date::Error
      nil
    end
end
