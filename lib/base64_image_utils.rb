# frozen_string_literal: true

# Utility class for handling base64-encoded image data
class Base64ImageUtils
  # Converts base64-encoded image string to a Tempfile
  def self.decode_to_tempfile(base64_string)
    raise ArgumentError, 'base64_string cannot be nil or empty' if base64_string.blank?

    base64_data = 
        if base64_string.include?(',')
        base64_string.split(',').last
        else
        base64_string
        end

    decoded_data = Base64.decode64(base64_data)

    content_type = 
        if base64_string.start_with?('data:')
            base64_string.split(';').first.split(':').last
        else
            'image/jpeg'
        end

    extension = extension_from_content_type(content_type)

    # Create a temporary file with the decoded image data
    temp_file = Tempfile.new(['image', ".#{extension}"])
    temp_file.binmode
    temp_file.write(decoded_data)
    temp_file.rewind

    temp_file
  end

  def self.content_type_from_string(base64_string)
    return 'image/jpeg' if base64_string.blank?

    if base64_string.start_with?('data:')
      base64_string.split(';').first.split(':').last
    else
      'image/jpeg'
    end
  end

  def self.extension_from_content_type(content_type)
    case content_type
    when 'image/png'
      'png'
    when 'image/gif'
      'gif'
    when 'image/webp'
      'webp'
    else
      'jpg'
    end
  end
end

