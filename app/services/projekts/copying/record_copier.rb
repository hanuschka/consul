class Projekts::Copying::RecordCopier
  # Columns that must never survive a copy: identity, timestamps, the
  # search vector rebuilt by the model, and counter caches whose value
  # belongs to the source's participant data.
  VOLATILE_COLUMNS = %w[id created_at updated_at tsv comments_count].freeze

  def initialize(id_map:)
    @id_map = id_map
    @blob_copier = Projekts::Copying::BlobCopier.new(id_map: id_map)
  end

  attr_reader :blob_copier

  def copy_record(source, attributes: {}, except: [])
    persist(source, build(source, attributes: attributes, except: except))
  end

  def copy_all(sources, attributes: {}, except: [])
    sources.map do |source|
      copy_record(source, attributes: attributes, except: except)
    end
  end

  # Split from `copy_record` for records whose attachment is validated for
  # presence (Image, Document): the blob has to be attached to the unsaved copy,
  # not added afterwards.
  # `attributes` is applied last so it wins over both the copied columns and the
  # copied translations -- otherwise naming a translated column there would be
  # silently overwritten by the source's value.
  def build(source, attributes: {}, except: [])
    copy = source.class.new(copyable_attributes(source, except))
    assign_translations(source, copy, except)
    copy.assign_attributes(attributes)

    copy
  end

  def persist(source, copy)
    copy.save!
    id_map.register(source, copy)

    copy
  end

  # The copy's own after_create callbacks scaffold a page, a map location, a
  # poll per voting phase and a budget per budget phase. Where such a scaffold
  # exists the source is applied onto it; where it does not, a new row is made.
  def overwrite_or_copy(source, scaffold, attributes: {}, except: [])
    if scaffold.blank?
      return copy_record(source, attributes: attributes, except: except)
    end

    overwrite(source, scaffold, attributes: attributes, except: except)
  end

  # For records the copy's own callbacks already built (the projekt page, the
  # default map location): apply the source's state onto the existing row
  # instead of inserting a second one.
  def overwrite(source, copy, attributes: {}, except: [])
    copy.assign_attributes(copyable_attributes(source, except))
    assign_translations(source, copy, except)
    copy.assign_attributes(attributes)
    copy.save!

    id_map.register(source, copy)

    copy
  end

  def copy_images(source, copy)
    copy_attachables(Image, :imageable, source, copy)
  end

  def copy_documents(source, copy)
    copy_attachables(Document, :documentable, source, copy)
  end

  def copy_attachments(source, copy)
    copy_images(source, copy)
    copy_documents(source, copy)
  end

  private

    attr_reader :id_map

    # Image and Document are the app's polymorphic attachment wrappers. Both
    # validate the attachment for presence, so the blob has to be attached to
    # the copy before it is saved -- and a source row without one is skipped
    # rather than raising. The owner is queried rather than reflected on: rows
    # exist for owner types that declare no association (Projekt carries Image
    # rows without including Imageable). Image already preloads its attachment
    # through a default scope; Document does not, hence the explicit preload.
    def copy_attachables(model, owner_key, source, copy)
      model.where(owner_key => source).with_attached_attachment.find_each do |record|
        next if !record.attachment.attached?

        record_copy = build(record, attributes: { owner_key => copy })
        blob_copier.copy_one(record.attachment, record_copy.attachment)
        persist(record, record_copy)
      end
    end

    # Globalize merges the translated attributes of the CURRENT locale into
    # `attributes`, so copying them here would flatten every locale onto one
    # (and stamp an empty translation on records that have none). They are
    # dropped and re-assigned per locale by `assign_translations` instead.
    def copyable_attributes(source, except)
      source.attributes.except(*VOLATILE_COLUMNS, *translated_names(source), *except.map(&:to_s))
    end

    # Globalize keeps translations in a side table that `dup` does not carry, so
    # every translated attribute is re-assigned locale by locale before the copy
    # is saved -- `validates_translation` only skips the untranslated attribute
    # when the record already has translations. `except` is honoured here too,
    # so it means the same thing for translated and plain columns.
    def assign_translations(source, copy, except)
      copied_names = translated_names(source) - except.map(&:to_s)
      return if copied_names.empty?

      source.translations.each do |translation|
        Globalize.with_locale(translation.locale) do
          copied_names.each do |name|
            copy.write_attribute(name, translation.read_attribute(name))
          end
        end
      end
    end

    def translated_names(source)
      return [] if !source.class.respond_to?(:translated_attribute_names)

      source.class.translated_attribute_names.map(&:to_s)
    end
end
