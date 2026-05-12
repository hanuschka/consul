module Masterportal
  module SvgSanitizer
    DISALLOWED_PATTERNS = [
      /<script\b/i,
      /\son\w+\s*=/i,
      /<foreignObject\b/i,
      /javascript\s*:/i
    ].freeze

    module_function

    def safe?(io_or_string)
      content =
        if io_or_string.respond_to?(:read)
          io_or_string.read
        else
          io_or_string.to_s
        end

      io_or_string.rewind if io_or_string.respond_to?(:rewind)

      DISALLOWED_PATTERNS.none? { |pattern| content.match?(pattern) }
    end
  end
end
