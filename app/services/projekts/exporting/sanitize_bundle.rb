# Everything that makes a copy bundle local, removed in one pass so the same
# bundle can be rebuilt on another instance.
#
# Three things cannot travel. Binaries: no blob, attachment wrapper or media
# library row leaves the instance. Rows of this instance: geozones, address
# districts, individual groups and projekt managers, whose ids name something
# else -- or nothing -- over there. Raw foreign keys inside `attributes`: they
# would attach a rebuilt record to whatever happens to sit at that id. The keys
# a copy genuinely needs were already promoted to `references` by the
# serializer, and are resolved through the IdMap, never assigned directly.
class Projekts::Exporting::SanitizeBundle < ApplicationService
  MEDIA_KEYS = %w[attachments images documents admin_images].freeze
  LOCAL_KEYS = %w[local_references].freeze
  REFERENCE_COLUMN = /(?:_id|_type)\z/
  HTML_MARKER = /<[a-z]|url\(/i

  def initialize(bundle:)
    @bundle = bundle
  end

  def call
    sanitize(bundle)
  end

  private

    attr_reader :bundle

    def sanitize(value)
      case value
      when Hash then sanitize_hash(value)
      when Array then value.map { |entry| sanitize(entry) }
      else value
      end
    end

    def sanitize_hash(hash)
      hash.except(*MEDIA_KEYS, *LOCAL_KEYS).each_with_object({}) do |(key, value), result|
        result[key] =
          case key
          when "attributes" then sanitize_attributes(value)
          when "translations" then sanitize_translations(value)
          else sanitize(value)
          end
      end
    end

    def sanitize_attributes(attributes)
      return sanitize(attributes) if !attributes.is_a?(Hash)

      attributes
        .reject { |name, _value| name.to_s.match?(REFERENCE_COLUMN) }
        .transform_values { |value| rewrite_stored_files(value) }
    end

    def sanitize_translations(translations)
      return sanitize(translations) if !translations.is_a?(Hash)

      translations.transform_values do |values|
        next values if !values.is_a?(Hash)

        values.transform_values { |value| rewrite_stored_files(value) }
      end
    end

    # Rewriting here means no address of this instance ever leaves it -- not in
    # a content block, not in a phase description, not in a milestone. Pictures
    # arrive as placeholders the admin can replace; links to a stored file
    # arrive inert rather than pointing at a blob only we have.
    def rewrite_stored_files(value)
      return value if !value.is_a?(String)
      return value if !value.match?(HTML_MARKER)

      Projekts::Exporting::StoredFileRewriter.call(value)
    end
end
