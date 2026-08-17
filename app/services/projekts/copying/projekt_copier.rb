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
  EXCLUDED_PAGE_COLUMNS = %w[projekt_id slug footer_key published_at].freeze

  # Forced on the copy regardless of the source, so a copy never appears in
  # public navigation or search results before an admin publishes it.
  HIDDEN_DRAFT_COLUMNS = {
    activated: false,
    show_in_navigation: false,
    show_in_overview_page: false,
    show_in_homepage: false
  }.freeze

  ALLOW_INDEXING_KEY = "projekt_feature.general.allow_indexing".freeze

  def initialize(source:, copy:, record_copier:)
    @source = source
    @copy = copy
    @record_copier = record_copier
    @blob_copier = record_copier.blob_copier
  end

  # The copy already exists as an empty shell, so its own after_create callbacks
  # have run: it has a page, a default settings set and a default map. Every
  # step below overwrites those rather than adding to them.
  def call
    record_copier.overwrite(
      source, copy,
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

    attr_reader :source, :copy, :record_copier, :blob_copier

    def copy_projekt_images
      blob_copier.copy_one(source.greeting_image, copy.greeting_image)
      blob_copier.copy_many(source.images, copy.images)
    end

    def copy_page
      source_page = source.page
      copy_page = copy.page
      return if source_page.blank? || copy_page.blank?

      copy_name = copy.name
      record_copier.overwrite(source_page, copy_page, except: EXCLUDED_PAGE_COLUMNS)
      restore_copy_title(copy_page, copy_name)

      # The projekt's banner lives as a polymorphic Image on the page, not on
      # the projekt.
      record_copier.copy_images(source_page, copy_page)

      blob_copier.copy_one(source_page.landing_desktop_header_image,
        copy_page.landing_desktop_header_image)
      blob_copier.copy_one(source_page.landing_mobile_header_image,
        copy_page.landing_mobile_header_image)
      blob_copier.copy_one(source_page.landing_desktop_header_video,
        copy_page.landing_desktop_header_video)
      blob_copier.copy_one(source_page.landing_mobile_header_video,
        copy_page.landing_mobile_header_video)
      blob_copier.copy_one(source_page.landing_site_logo_for_transparent_background,
        copy_page.landing_site_logo_for_transparent_background)
      blob_copier.copy_one(source_page.landing_site_logo_for_white_background,
        copy_page.landing_site_logo_for_white_background)
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

      source.projekt_settings.each do |setting|
        next if column_backed_keys.include?(setting.key)

        existing = existing_settings[setting.key]

        if existing.present?
          existing.update!(value: setting.value)
        else
          copy.projekt_settings.create!(key: setting.key, value: setting.value)
        end
      end

      copy.projekt_settings.find_by(key: ALLOW_INDEXING_KEY)&.update!(value: "")
    end

    def copy_map
      Projekts::Copying::MapCopier.call(
        source: source, copy: copy,
        record_copier: record_copier
      )
    end

    def copy_affiliations
      copy.geozone_affiliations = source.geozone_affiliations
      copy.registered_address_district_affiliations = source.registered_address_district_affiliations
      copy.individual_group_values = source.individual_group_values
    end

    def copy_tags
      copy.tag_list = source.tag_list
      copy.ml_tag_list = source.ml_tag_list
      copy.milestone_tag_list = source.milestone_tag_list
      copy.save!
    end

    def copy_sdg_relations
      record_copier.copy_all(source.sdg_relations, attributes: { relatable: copy })
    end

    def copy_manager_assignments
      source.projekt_manager_assignments.each do |assignment|
        existing = copy.projekt_manager_assignments
          .find_or_initialize_by(projekt_manager_id: assignment.projekt_manager_id)
        existing.permissions |= assignment.permissions
        existing.save!
      end
    end

    def copy_milestones
      source.milestones.each do |milestone|
        milestone_copy = record_copier.copy_record(milestone, attributes: { milestoneable: copy })
        record_copier.copy_attachments(milestone, milestone_copy)
      end
    end

    def copy_progress_bars
      record_copier.copy_all(source.progress_bars, attributes: { progressable: copy })
    end

    def copy_media_library
      AdminImage.where(projekt_id: source.id).find_each do |admin_image|
        admin_image_copy = record_copier.build(admin_image, attributes: { projekt_id: copy.id })
        blob_copier.copy_one(admin_image.storage_data, admin_image_copy.storage_data)
        record_copier.persist(admin_image, admin_image_copy)
      end

      record_copier.copy_attachments(source, copy)
    end

    # parent_id still points at the source's items here; the rewiring pass
    # resolves it once every item has a copy.
    def copy_navbar_items
      record_copier.copy_all(source.navbar_items, attributes: { projekt_id: copy.id })
    end
end
