class Projekts::Copying::Serializing::RecordSerializer
  # Columns that must never survive a copy: identity, timestamps, the search
  # vector rebuilt by the model, and counter caches whose value belongs to the
  # source's participant data.
  VOLATILE_COLUMNS = %w[id created_at updated_at tsv comments_count].freeze

  # `references` names the foreign keys the rewiring pass resolves once the
  # whole graph exists. They are read out separately because an export strips
  # every raw id from `attributes` -- these are the ones that must survive it.
  def self.call(record, except: [], references: [], attachments: [])
    new(record, except: except, references: references, attachments: attachments).call
  end

  def initialize(record, except: [], references: [], attachments: [])
    @record = record
    @except = except.map(&:to_s)
    @references = references.map(&:to_s)
    @attachments = attachments
  end

  def call
    {
      "model" => record.class.name,
      "source_id" => record.id,
      "attributes" => plain_attributes,
      "translations" => translations,
      "references" => serialized_references,
      "attachments" => serialized_attachments
    }
  end

  private

    attr_reader :record, :except, :references, :attachments

    # Globalize merges the translated attributes of the CURRENT locale into
    # `attributes`, so keeping them here would flatten every locale onto one
    # (and stamp an empty translation on records that have none). They are
    # dropped and emitted per locale instead.
    def plain_attributes
      record.attributes.except(*VOLATILE_COLUMNS, *translated_names, *except).as_json
    end

    def translations
      names = translated_names - except
      return {} if names.empty?

      record.translations.each_with_object({}) do |translation, result|
        result[translation.locale.to_s] =
          names.index_with { |name| translation.read_attribute(name) }.as_json
      end
    end

    def serialized_references
      references.index_with { |name| record.read_attribute(name) }.compact
    end

    # Blobs are named by id: within one instance the copier duplicates them,
    # and an export drops the whole key rather than carrying a binary.
    # Keyed by string, like every other key here: a local copy reads the bundle
    # as it is built, an import reads it back out of JSON, and both have to find
    # the same key.
    def serialized_attachments
      attachments.each_with_object({}) do |name, result|
        ids = blob_ids(record.public_send(name))
        next if ids.blank?

        result[name.to_s] = ids
      end
    end

    def blob_ids(attached)
      return nil if attached.blank?
      return attached.attachments.map(&:blob_id) if attached.is_a?(ActiveStorage::Attached::Many)

      attached.blob&.id
    end

    def translated_names
      return [] if !record.class.respond_to?(:translated_attribute_names)

      record.class.translated_attribute_names.map(&:to_s)
    end
end
