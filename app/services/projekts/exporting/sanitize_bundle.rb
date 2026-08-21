# Everything that makes a copy bundle local, removed in one pass so the same
# bundle can be rebuilt on another instance.
#
# Three things cannot travel. Binaries: no blob, attachment wrapper or media
# library row leaves the instance. Rows of this instance: geozones, address
# districts, individual groups, projekt managers, and any reference that names
# a record outside the projekt. Foreign keys inside `attributes`: they would
# attach a rebuilt record to whatever happens to sit at that id. The keys a copy
# genuinely needs were promoted to `references` by the serializer and are
# resolved through the IdMap, never assigned directly.
#
# Also run by the importer before it rebuilds: an export is sanitized by the
# instance that sends it, which is the wrong side of the trust boundary to be
# the only one enforcing this.
class Projekts::Exporting::SanitizeBundle < ApplicationService
  MEDIA_KEYS = %w[attachments images documents admin_images].freeze
  LOCAL_KEYS = %w[local_references].freeze
  HTML_MARKER = /<[a-z]|url\(/i

  # An integer column named `<something>_id` is a foreign key here, whether or
  # not a belongs_to declares it -- several tables carry pre-polymorphic ones.
  # A string one is not: `projekt_livestreams.external_id` names a stream on a
  # video platform and `map_locations.mapbox_style_id` a style on Mapbox, and
  # both mean the same thing on any instance.
  FOREIGN_KEY_COLUMN = /_id\z/
  FOREIGN_KEY_TYPES = %i[integer bigint].freeze

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
      model_name = hash["model"]

      hash.except(*MEDIA_KEYS, *LOCAL_KEYS).each_with_object({}) do |(key, value), result|
        result[key] =
          case key
          when "attributes" then sanitize_attributes(value, model_name)
          when "translations" then sanitize_translations(value)
          else sanitize(value)
          end
      end
    end

    def sanitize_attributes(attributes, model_name)
      return sanitize(attributes) if !attributes.is_a?(Hash)

      dropped = dropped_columns(model_name)

      attributes
        .except(*dropped)
        .transform_values { |value| rewrite_stored_files(value) }
    end

    # Only the columns that really are references: the polymorphic type columns
    # a belongs_to declares, and the integer ids. Matching the name alone would
    # take `votation_types.vote_type` with it -- an enum, not a reference -- and
    # every imported poll question would arrive without one.
    def dropped_columns(model_name)
      model = permitted_model(model_name)
      return [] if model.blank?

      @dropped_columns ||= {}
      @dropped_columns[model.name] ||= foreign_key_columns(model) + polymorphic_type_columns(model)
    end

    def foreign_key_columns(model)
      model.columns.filter_map do |column|
        next if !column.name.match?(FOREIGN_KEY_COLUMN)
        next if FOREIGN_KEY_TYPES.exclude?(column.type)

        column.name
      end
    end

    def polymorphic_type_columns(model)
      model.reflect_on_all_associations(:belongs_to).filter_map do |reflection|
        next if !reflection.polymorphic?

        reflection.foreign_type.to_s
      end
    end

    def permitted_model(model_name)
      model = model_name.to_s.safe_constantize
      return nil if !model.is_a?(Class) || !model.respond_to?(:columns)
      return nil if !model.table_exists?

      model
    rescue StandardError
      nil
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
    # arrive as placeholders the admin can replace; links and frames pointing at
    # a stored file arrive inert rather than at a blob only we have.
    def rewrite_stored_files(value)
      return value if !value.is_a?(String)
      return value if !value.match?(HTML_MARKER)

      Projekts::Exporting::StoredFileRewriter.call(value)
    end
end
