# Base for every endpoint that changes the instance configuration: only clients
# granted the configuration right get through, and each change is audited
# under the client's content author with the client id on the audit row.
class Api::Configuration::BaseController < Api::BaseController
  before_action :check_configuration_access!
  around_action :audit_changes_as_client

  private

    def render_record_errors(record)
      render_invalid_values(record.errors.to_hash(true).transform_keys(&:to_s))
    end

    # Globalize keeps the errors of a translation row (a language written
    # without its required title) on that row, not on the record; they are
    # reported as translations.<locale>.<attribute>.
    def render_translated_record_errors(record)
      errors = record.errors.to_hash(true).transform_keys(&:to_s)

      record.translations.each do |translation|
        translation.errors.to_hash(true).each do |attribute, messages|
          errors["translations.#{translation.locale}.#{attribute}"] = messages
        end
      end

      render_invalid_values(errors)
    end

    # Checks each attribute present in the body against its definition and
    # returns the typed values plus the errors per attribute.
    def parse_typed_attributes(raw_attributes, definitions)
      attribute_values = {}
      errors = {}

      definitions.each do |name, definition|
        next if !raw_attributes.key?(name)

        result = TypedValueParser.parse(raw_attributes[name], definition)

        if result.valid?
          attribute_values[name] = result.value
        else
          errors[name] = [result.error]
        end
      end

      [attribute_values, errors]
    end

    def unknown_attribute_errors(raw_attributes, writable_attribute_names)
      (raw_attributes.keys - writable_attribute_names).index_with { ["is not a writable attribute"] }
    end

    # HTML is cleaned on the way in, so no script ever reaches the database.
    def sanitize_translated_html(translations, attribute_name)
      translations.transform_values do |attributes|
        if attributes[attribute_name].present?
          attributes.merge(attribute_name => AdminWYSIWYGSanitizer.new.sanitize(attributes[attribute_name]))
        else
          attributes
        end
      end
    end

    def attachment_url(attachment)
      return nil if !attachment&.attached?

      rails_blob_url(attachment, **UrlOptions.default)
    end

    def serialize_attachment(attachment)
      return nil if !attachment&.attached?

      {
        url: attachment_url(attachment),
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size
      }
    end

    # Swapping or removing a file changes no column, so the audited gem would
    # not see it; the change is written as an audit row of its own.
    def audit_attachment_change(record, attribute_name, previous_blob, current_blob)
      ::Audit.create!(
        auditable: record,
        action: "update",
        audited_changes: {
          attribute_name.to_s => [blob_audit_label(previous_blob), blob_audit_label(current_blob)]
        }
      )
    end

    def blob_audit_label(blob)
      return nil if blob.nil?

      "#{blob.filename} (#{blob.checksum})"
    end

    # Files arrive base64 encoded, bare or as a data URI.
    def decoded_attachment(encoded_file, filename_stem)
      if !encoded_file.is_a?(String) || encoded_file.blank?
        raise ActionController::ParameterMissing, :attachment
      end

      Base64Attachable.build(encoded_file, filename_stem:)
    end

    def available_locales
      I18n.available_locales.map(&:to_s)
    end

    # Translations arrive as { "de" => { "title" => "…" }, "en" => { … } }.
    # Each language is written through Globalize directly, so no translation ids
    # are needed.
    def assign_translations(record, translations)
      translations.each do |locale, attributes|
        Globalize.with_locale(locale) { record.assign_attributes(attributes) }
      end
    end

    # Several languages in one request switch machine translation off: it would
    # otherwise overwrite the languages the client just wrote.
    def save_with_translations(record, translations)
      if translations.size > 1
        MachineTranslation.suppress { record.save }
      else
        record.save
      end
    end

    def permitted_translations(translations_param, attribute_names)
      if !translations_param.is_a?(ActionController::Parameters)
        return {}
      end

      translations_param
        .permit(available_locales.index_with { attribute_names })
        .to_h
        .slice(*available_locales)
    end

    def serialize_translations(record, attribute_names)
      record.translations.to_h do |translation|
        [translation.locale.to_s, attribute_names.index_with { translation[it] }]
      end
    end

    def unsupported_locales_error(translations_param)
      return if !translations_param.is_a?(ActionController::Parameters)

      unknown_locales = translations_param.to_unsafe_h.keys - available_locales
      return if unknown_locales.empty?

      { "translations" => ["contain unsupported languages: #{unknown_locales.join(", ")}"] }
    end
end
