class Projekts::Copying::Serializing::ProjektSerializer < ApplicationService
  EXCLUDED_COLUMNS = Projekts::Copying::ProjektCopier::EXCLUDED_COLUMNS
  EXCLUDED_PAGE_COLUMNS = Projekts::Copying::ProjektCopier::EXCLUDED_PAGE_COLUMNS

  # The key is regenerated against the copy's id, and ai_generation_data
  # describes a generation run that happened for the source.
  EXCLUDED_CONTENT_BLOCK_COLUMNS = %w[key ai_generation_data].freeze

  PAGE_ATTACHMENTS = Projekts::Copying::ProjektCopier::PAGE_ATTACHMENTS

  def initialize(source:)
    @source = source
  end

  def call
    {
      "projekt" => projekt_node,
      "page" => page_node,
      "projekt_settings" => setting_nodes,
      "map" => Projekts::Copying::Serializing::MapSerializer.call(source: source),
      "tags" => tag_lists,
      "sdg_relations" => Projekts::Copying::Serializing::SdgCodeSerializer.call(source: source),
      "milestones" => attachable_nodes(source.milestones),
      "progress_bars" => serialize_all(source.progress_bars),
      "navbar_items" => navbar_item_nodes,
      "content_blocks" => content_block_nodes,
      "admin_images" => admin_image_nodes,
      "local_references" => local_references
    }
  end

  private

    attr_reader :source

    # The projekt's own name travels even though a local copy will not use it:
    # the copy is named by its shell, an import adopts the source's name, and
    # both decide that before the copier runs.
    def projekt_node
      Projekts::Copying::Serializing::RecordSerializer
        .call(source, except: EXCLUDED_COLUMNS - %w[name], attachments: %i[greeting_image images])
        .merge(Projekts::Copying::Serializing::AttachableSerializer.call(record: source))
    end

    def page_node
      page = source.page
      return nil if page.blank?

      Projekts::Copying::Serializing::RecordSerializer
        .call(page, except: EXCLUDED_PAGE_COLUMNS, attachments: PAGE_ATTACHMENTS)
        .merge(Projekts::Copying::Serializing::AttachableSerializer.call(record: page))
    end

    def setting_nodes
      source.projekt_settings.map do |setting|
        { "key" => setting.key, "value" => setting.value }
      end
    end

    def tag_lists
      {
        "tag_list" => source.tag_list.to_a,
        "ml_tag_list" => source.ml_tag_list.to_a,
        "milestone_tag_list" => source.milestone_tag_list.to_a
      }
    end

    # parent_id, landing_page_id and linked_page_id all point at real rows, so
    # they travel as references: within one instance an unmapped one still
    # resolves, and an export drops them along with every other raw id.
    def navbar_item_nodes
      source.navbar_items.map do |navbar_item|
        Projekts::Copying::Serializing::RecordSerializer.call(
          navbar_item, references: %w[parent_id landing_page_id linked_page_id]
        )
      end
    end

    # The source key pairs a block's per-locale rows with each other, so it
    # travels beside the node even though the key itself is regenerated.
    def content_block_nodes
      source.content_blocks.order(:position, :id).map do |content_block|
        Projekts::Copying::Serializing::RecordSerializer
          .call(content_block, except: EXCLUDED_CONTENT_BLOCK_COLUMNS)
          .merge("source_key" => content_block.key)
      end
    end

    def admin_image_nodes
      AdminImage.where(projekt_id: source.id).map do |admin_image|
        Projekts::Copying::Serializing::RecordSerializer.call(
          admin_image, attachments: %i[storage_data]
        )
      end
    end

    # Rows of THIS instance, dropped wholesale by an export.
    def local_references
      {
        "geozone_affiliation_ids" => source.geozone_affiliations.map(&:id),
        "registered_address_district_affiliation_ids" =>
          source.registered_address_district_affiliations.map(&:id),
        "individual_group_value_ids" => source.individual_group_values.map(&:id),
        "projekt_manager_assignments" => source.projekt_manager_assignments.map do |assignment|
          {
            "projekt_manager_id" => assignment.projekt_manager_id,
            "permissions" => assignment.permissions
          }
        end
      }
    end

    def attachable_nodes(records)
      records.map do |record|
        Projekts::Copying::Serializing::RecordSerializer
          .call(record)
          .merge(Projekts::Copying::Serializing::AttachableSerializer.call(record: record))
      end
    end

    def serialize_all(records)
      records.map { |record| Projekts::Copying::Serializing::RecordSerializer.call(record) }
    end
end
