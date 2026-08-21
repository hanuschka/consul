class Projekts::Copying::ProjektCopier < ApplicationService
  # Rebuilt by the copy's own callbacks, tied to the source's participants, or
  # unique per record -- none of them may be carried over. `name`, `order_number`
  # and the copy columns are owned by the shell: taking the source's
  # order_number over the one `set_order` assigned would leave two projekts
  # sharing a position, which `sort_by_order_number` cannot break.
  EXCLUDED_COLUMNS = %w[
    name order_number preview_code published_at content_updated_at
    banner_image_generation_status copy_status copied_from_projekt_id
    import_file_status import_file_data imported_by_ai
    whatsapp_broadcast_sent_at whatsapp_broadcast_slug
    on_dt_global_overview from_dt special special_name
  ].freeze

  # The page slug and footer key are unique; the slug was generated for the copy
  # by Projekt#create_corresponding_page and the footer key belongs to whichever
  # page already claimed it.
  EXCLUDED_PAGE_COLUMNS = %w[projekt_id slug footer_key].freeze

  # Attachments the landing page carries directly, rather than through an Image
  # or Document row.
  PAGE_ATTACHMENTS = %i[
    landing_desktop_header_image
    landing_mobile_header_image
    landing_desktop_header_video
    landing_mobile_header_video
    landing_site_logo_for_transparent_background
    landing_site_logo_for_white_background
  ].freeze

  # Forced on the copy regardless of the source, so a copy never appears in
  # public navigation or search results before an admin publishes it. `activated`
  # is what the admin dashboard counts as a draft.
  HIDDEN_DRAFT_COLUMNS = {
    activated: false,
    show_in_navigation: false,
    show_in_overview_page: false,
    show_in_homepage: false
  }.freeze

  # The page carries the app's own draft/published flag: it is what
  # Projekt#published?, the public page controller and the global-overview
  # export all read. A copy of a live projekt would otherwise inherit
  # "published" while its projekt sits deactivated.
  DRAFT_PAGE_COLUMNS = {
    status: "draft",
    published_at: nil
  }.freeze

  ALLOW_INDEXING_KEY = "projekt_feature.general.allow_indexing".freeze

  def initialize(bundle:, copy:, record_copier:)
    @bundle = bundle
    @copy = copy
    @record_copier = record_copier
  end

  # The copy already exists as an empty shell, so its own after_create callbacks
  # have run: it has a page, a default settings set and a default map. Every
  # step below overwrites those rather than adding to them.
  def call
    record_copier.overwrite(
      projekt_node, copy,
      attributes: HIDDEN_DRAFT_COLUMNS,
      except: EXCLUDED_COLUMNS
    )

    copy_projekt_images
    copy_page
    copy_settings
    copy_map
    copy_affiliations
    copy_tags
    copy_sdg_relations
    copy_manager_assignments
    copy_milestones
    copy_progress_bars
    copy_media_library
    copy_navbar_items

    copy
  end

  private

    attr_reader :bundle, :copy, :record_copier

    def projekt_node
      bundle["projekt"] || {}
    end

    def local_references
      bundle["local_references"] || {}
    end

    def copy_projekt_images
      record_copier.copy_attachment(projekt_node, :greeting_image, copy.greeting_image)
      record_copier.copy_attachment_list(projekt_node, :images, copy.images)
    end

    def copy_page
      page_node = bundle["page"]
      copy_page = copy.page
      return if page_node.blank? || copy_page.blank?

      copy_name = copy.name
      record_copier.overwrite(
        page_node, copy_page,
        attributes: DRAFT_PAGE_COLUMNS,
        except: EXCLUDED_PAGE_COLUMNS
      )
      restore_copy_title(copy_page, copy_name)

      # The projekt's banner lives as a polymorphic Image on the page, not on
      # the projekt.
      record_copier.copy_images(page_node, copy_page)

      PAGE_ATTACHMENTS.each do |name|
        record_copier.copy_attachment(page_node, name, copy_page.public_send(name))
      end
    end

    # SiteCustomization::Page#sync_projekt_name writes the page title back onto
    # projekt.name, so taking over the source's title would silently undo the
    # copy's name. The title cannot simply be left out of the copy instead:
    # Page validates its translated title for presence, so every locale the
    # source has needs one.
    def restore_copy_title(page, copy_name)
      page.translations.reload.each do |translation|
        Globalize.with_locale(translation.locale) do
          page.title = copy_name
        end
      end

      page.save!
      copy.reload
    end

    # The seven settings in KEY_TO_COLUMN are mirrored from the copy's own
    # columns by Projekt#create_default_settings, so writing their rows here
    # would immediately disagree with the columns the readers trust.
    def copy_settings
      column_backed_keys = Projekt::KEY_TO_COLUMN.keys
      existing_settings = copy.projekt_settings.index_by(&:key)

      Array(bundle["projekt_settings"]).each do |setting|
        key = setting["key"]
        next if column_backed_keys.include?(key)

        existing = existing_settings[key]

        if existing.present?
          existing.update!(value: setting["value"])
        else
          copy.projekt_settings.create!(key: key, value: setting["value"])
        end
      end

      copy.projekt_settings.find_by(key: ALLOW_INDEXING_KEY)&.update!(value: "")
    end

    def copy_map
      Projekts::Copying::MapCopier.call(
        node: bundle["map"], copy: copy,
        record_copier: record_copier
      )
    end

    # Empty on an imported bundle: geozones, address districts and individual
    # groups are rows of this instance, and a projekt re-attached to a
    # same-named row elsewhere would admit or exclude the wrong people.
    def copy_affiliations
      copy.geozone_affiliations =
        Geozone.where(id: local_references["geozone_affiliation_ids"])
      copy.registered_address_district_affiliations =
        RegisteredAddress::District.where(
          id: local_references["registered_address_district_affiliation_ids"]
        )
      copy.individual_group_values =
        IndividualGroupValue.where(id: local_references["individual_group_value_ids"])
    end

    def copy_tags
      tag_lists = bundle["tags"] || {}

      copy.tag_list = Array(tag_lists["tag_list"])
      copy.ml_tag_list = Array(tag_lists["ml_tag_list"])
      copy.milestone_tag_list = Array(tag_lists["milestone_tag_list"])
      copy.save!
    end

    def copy_sdg_relations
      related_sdgs = Projekts::Copying::Serializing::SdgCodeSerializer
        .resolve(bundle["sdg_relations"])

      related_sdgs.each do |related_sdg|
        copy.sdg_relations.find_or_create_by!(related_sdg: related_sdg)
      end
    end

    def copy_manager_assignments
      Array(local_references["projekt_manager_assignments"]).each do |assignment|
        existing = copy.projekt_manager_assignments
          .find_or_initialize_by(projekt_manager_id: assignment["projekt_manager_id"])
        existing.permissions |= Array(assignment["permissions"])
        existing.save!
      end
    end

    def copy_milestones
      Array(bundle["milestones"]).each do |node|
        milestone_copy = record_copier.copy_record(node, attributes: { milestoneable: copy })
        record_copier.copy_attachments(node, milestone_copy)
      end
    end

    def copy_progress_bars
      record_copier.copy_all(bundle["progress_bars"], attributes: { progressable: copy })
    end

    def copy_media_library
      Array(bundle["admin_images"]).each do |node|
        admin_image_copy = record_copier.build(node, attributes: { projekt_id: copy.id })
        record_copier.copy_attachment(node, :storage_data, admin_image_copy.storage_data)
        record_copier.persist(node, admin_image_copy)
      end

      record_copier.copy_attachments(projekt_node, copy)
    end

    # parent_id still points at the source's items here; the rewiring pass
    # resolves it once every item has a copy.
    def copy_navbar_items
      record_copier.copy_all(bundle["navbar_items"], attributes: { projekt_id: copy.id })
    end
end
