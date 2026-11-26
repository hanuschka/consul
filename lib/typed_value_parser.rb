require "uri"

module TypedValueParser
  TYPES = %i[boolean integer decimal color url link string text select multi_select date].freeze

  COLOR_FORMAT = /\A#(\h{3}|\h{4}|\h{6}|\h{8})\z/
  INTEGER_FORMAT = /\A-?\d+\z/
  DECIMAL_FORMAT = /\A-?\d+(\.\d+)?\z/
  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  URL_SCHEMES = %w[http https].freeze

  STRING_MAX_LENGTH = 255
  TEXT_MAX_LENGTH = 10_000
  URL_MAX_LENGTH = 2048

  INVALID_URL_MESSAGE = "must be an absolute http or https URL".freeze
  INVALID_LINK_MESSAGE = "must be an absolute http or https URL or a path starting with /".freeze
  INVALID_DATE_MESSAGE = "must be a date in the format YYYY-MM-DD".freeze

  Definition = Struct.new(
    :type, :options, :allow_blank, :min, :max, :max_length,
    keyword_init: true
  ) do
    def initialize(type:, options: [], allow_blank: false, min: nil, max: nil, max_length: nil)
      if !TYPES.include?(type)
        raise ArgumentError, "Unknown type: #{type}"
      end

      super
    end
  end

  Result = Struct.new(:value, :error, keyword_init: true) do
    def valid?
      error.nil?
    end
  end

  module_function

  def parse(raw_value, definition)
    if blank_value?(raw_value)
      return parse_blank(definition)
    end

    case definition.type
    when :boolean then parse_boolean(raw_value)
    when :integer then parse_integer(raw_value, definition)
    when :decimal then parse_decimal(raw_value, definition)
    when :color then parse_color(raw_value)
    when :url then parse_url(raw_value)
    when :link then parse_link(raw_value)
    when :string then parse_string(raw_value, definition, STRING_MAX_LENGTH)
    when :text then parse_string(raw_value, definition, TEXT_MAX_LENGTH)
    when :select then parse_select(raw_value, definition)
    when :multi_select then parse_multi_select(raw_value, definition)
    when :date then parse_date(raw_value)
    end
  end

  def blank_value?(raw_value)
    raw_value.nil? || (raw_value.is_a?(String) && raw_value.strip.empty?)
  end

  def parse_blank(definition)
    if definition.type == :boolean
      invalid("must be true or false")
    elsif definition.allow_blank
      Result.new(value: nil)
    else
      invalid("can't be blank")
    end
  end

  def parse_boolean(raw_value)
    case raw_value
    when true, "true" then Result.new(value: true)
    when false, "false" then Result.new(value: false)
    else invalid("must be true or false")
    end
  end

  def parse_integer(raw_value, definition)
    integer_value =
      if raw_value.is_a?(Integer)
        raw_value
      elsif raw_value.is_a?(String) && raw_value.strip.match?(INTEGER_FORMAT)
        raw_value.strip.to_i
      end

    if integer_value.nil?
      invalid("must be a whole number")
    elsif definition.min && integer_value < definition.min
      invalid("must be greater than or equal to #{definition.min}")
    elsif definition.max && integer_value > definition.max
      invalid("must be less than or equal to #{definition.max}")
    else
      Result.new(value: integer_value)
    end
  end

  def parse_decimal(raw_value, definition)
    decimal_value =
      if raw_value.is_a?(Numeric) && !raw_value.is_a?(Complex)
        raw_value.to_f
      elsif raw_value.is_a?(String) && raw_value.strip.match?(DECIMAL_FORMAT)
        raw_value.strip.to_f
      end

    if decimal_value.nil?
      invalid("must be a number")
    elsif definition.min && decimal_value < definition.min
      invalid("must be greater than or equal to #{definition.min}")
    elsif definition.max && decimal_value > definition.max
      invalid("must be less than or equal to #{definition.max}")
    else
      Result.new(value: decimal_value)
    end
  end

  def parse_color(raw_value)
    if raw_value.is_a?(String) && raw_value.strip.match?(COLOR_FORMAT)
      Result.new(value: raw_value.strip.downcase)
    else
      invalid("must be a hex colour such as #004a83")
    end
  end

  def parse_url(raw_value)
    if !raw_value.is_a?(String)
      return invalid(INVALID_URL_MESSAGE)
    end

    url = raw_value.strip

    if url.length > URL_MAX_LENGTH
      return invalid("is too long (maximum is #{URL_MAX_LENGTH} characters)")
    end

    parsed_url = URI.parse(url)

    if URL_SCHEMES.include?(parsed_url.scheme&.downcase) && parsed_url.host.present?
      Result.new(value: url)
    else
      invalid(INVALID_URL_MESSAGE)
    end
  rescue URI::InvalidURIError
    invalid(INVALID_URL_MESSAGE)
  end

  def parse_link(raw_value)
    if raw_value.is_a?(String) && site_path?(raw_value.strip)
      return Result.new(value: raw_value.strip)
    end

    url_result = parse_url(raw_value)

    if url_result.valid?
      url_result
    else
      invalid(INVALID_LINK_MESSAGE)
    end
  end

  def site_path?(path)
    path.start_with?("/") && !path.start_with?("//") &&
      path.length <= URL_MAX_LENGTH && !path.match?(/\s/)
  end

  def parse_string(raw_value, definition, default_max_length)
    if !raw_value.is_a?(String) && !raw_value.is_a?(Numeric)
      return invalid("must be a string")
    end

    string_value = raw_value.to_s.strip
    max_length = definition.max_length || default_max_length

    if string_value.length > max_length
      invalid("is too long (maximum is #{max_length} characters)")
    elsif definition.type == :string && string_value.match?(/[\r\n]/)
      invalid("must be a single line")
    else
      Result.new(value: string_value)
    end
  end

  def parse_select(raw_value, definition)
    option_value = raw_value.to_s

    if definition.options.map(&:to_s).include?(option_value)
      Result.new(value: option_value)
    else
      invalid("must be one of: #{definition.options.join(", ")}")
    end
  end

  def parse_multi_select(raw_value, definition)
    if !raw_value.is_a?(Array)
      return invalid("must be a list of values")
    end

    selected_options = raw_value.map(&:to_s).uniq
    unknown_options = selected_options - definition.options.map(&:to_s)

    if unknown_options.any?
      invalid("contains unknown values: #{unknown_options.join(", ")}")
    else
      Result.new(value: selected_options)
    end
  end

  def parse_date(raw_value)
    date_string = raw_value.to_s.strip
    if !date_string.match?(DATE_FORMAT)
      return invalid(INVALID_DATE_MESSAGE)
    end

    Result.new(value: Date.iso8601(date_string).iso8601)
  rescue Date::Error
    invalid(INVALID_DATE_MESSAGE)
  end

  def invalid(message)
    Result.new(error: message)
  end
end
