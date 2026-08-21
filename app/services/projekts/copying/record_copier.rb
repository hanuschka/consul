class Projekts::Copying::RecordCopier
  def initialize(id_map:, reader:, blob_copier:)
    @id_map = id_map
    @reader = reader
    @blob_copier = blob_copier
  end

  attr_reader :blob_copier

  def copy_record(node, attributes: {}, except: [])
    persist(node, build(node, attributes: attributes, except: except))
  end

  def copy_all(nodes, attributes: {}, except: [])
    Array(nodes).map do |node|
      copy_record(node, attributes: attributes, except: except)
    end
  end

  # Split from `copy_record` for records whose attachment is validated for
  # presence (Image, Document): the blob has to be attached to the unsaved copy,
  # not added afterwards.
  # `attributes` is applied last so it wins over both the copied columns and the
  # copied translations -- otherwise naming a translated column there would be
  # silently overwritten by the source's value.
  def build(node, attributes: {}, except: [])
    copy = reader.model(node).new(reader.attributes(node, except: except))
    assign_translations(node, copy, except)
    copy.assign_attributes(attributes)

    copy
  end

  def persist(node, copy)
    copy.save!
    register(node, copy)

    copy
  end

  # The copy's own after_create callbacks scaffold a page, a map location, a
  # poll per voting phase and a budget per budget phase. Where such a scaffold
  # exists the node is applied onto it; where it does not, a new row is made.
  def overwrite_or_copy(node, scaffold, attributes: {}, except: [])
    if scaffold.blank?
      return copy_record(node, attributes: attributes, except: except)
    end

    overwrite(node, scaffold, attributes: attributes, except: except)
  end

  # For records the copy's own callbacks already built (the projekt page, the
  # default map location): apply the node onto the existing row instead of
  # inserting a second one.
  def overwrite(node, copy, attributes: {}, except: [])
    copy.assign_attributes(reader.attributes(node, except: except))
    assign_translations(node, copy, except)
    copy.assign_attributes(attributes)
    copy.save!

    register(node, copy)

    copy
  end

  # An export drops every media key, so on that path these find nothing and do
  # nothing -- which is what keeps the copiers free of a "do binaries travel"
  # branch.
  def copy_images(node, copy)
    blob_copier.copy_attachables(Image, :imageable, node["images"], copy, record_copier: self)
  end

  def copy_documents(node, copy)
    blob_copier.copy_attachables(
      Document, :documentable, node["documents"], copy, record_copier: self
    )
  end

  def copy_attachments(node, copy)
    copy_images(node, copy)
    copy_documents(node, copy)
  end

  def copy_attachment(node, name, copy_attached)
    blob_copier.copy_one(node.dig("attachments", name.to_s), copy_attached)
  end

  def copy_attachment_list(node, name, copy_attached)
    blob_copier.copy_many(node.dig("attachments", name.to_s), copy_attached)
  end

  private

    attr_reader :id_map, :reader

    def register(node, copy)
      id_map.register_source(copy.class.base_class.name, reader.source_id(node), copy)
    end

    # Globalize keeps translations in a side table, so every translated
    # attribute is assigned locale by locale before the copy is saved --
    # `validates_translation` only skips the untranslated attribute when the
    # record already has translations.
    def assign_translations(node, copy, except)
      translations = reader.translations(node, except: except)
      return if translations.blank?

      translations.each do |locale, values|
        Globalize.with_locale(locale) do
          values.each { |name, value| copy.write_attribute(name, value) }
        end
      end
    end
end
