class Api::Configuration::LandingPagesController < Api::Configuration::BaseController
  TRANSLATED_ATTRIBUTES = %i[title subtitle header_title content].freeze
  DEFAULT_NAVIGATION_LINK_COLOR = "#000000".freeze

  BOOLEAN_DEFINITION = TypedValueParser::Definition.new(type: :boolean)
  COLOR_DEFINITION = TypedValueParser::Definition.new(type: :color, allow_blank: true)

  ATTRIBUTE_DEFINITIONS = {
    "slug" => TypedValueParser::Definition.new(type: :string),
    "status" => TypedValueParser::Definition.new(
      type: :select, options: ::SiteCustomization::Page::VALID_STATUSES
    ),
    "landing_show_in_top_nav" => BOOLEAN_DEFINITION,
    "landing_hide_title_and_subtitle" => BOOLEAN_DEFINITION,
    "landing_site_logo_follow_to_landing_page" => BOOLEAN_DEFINITION,
    "landing_navigation_link_color" => COLOR_DEFINITION,
    "brand_color" => COLOR_DEFINITION
  }.freeze

  # Read through explicit lambdas so no attachment is looked up by a name the
  # client sent.
  ATTACHMENTS = {
    "landing_desktop_header_image" => ->(page) { page.landing_desktop_header_image },
    "landing_mobile_header_image" => ->(page) { page.landing_mobile_header_image },
    "landing_desktop_header_video" => ->(page) { page.landing_desktop_header_video },
    "landing_mobile_header_video" => ->(page) { page.landing_mobile_header_video },
    "landing_site_logo_for_transparent_background" => lambda do |page|
      page.landing_site_logo_for_transparent_background
    end,
    "landing_site_logo_for_white_background" => ->(page) { page.landing_site_logo_for_white_background }
  }.freeze

  # The page model checks only the two videos; images and logos are limited
  # here to raster formats a browser shows inline (no SVG, which can carry
  # script).
  IMAGE_ATTACHMENT_NAMES = %w[
    landing_desktop_header_image
    landing_mobile_header_image
    landing_site_logo_for_transparent_background
    landing_site_logo_for_white_background
  ].freeze
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  before_action :find_landing_page, only: [:show, :update, :destroy]

  def index
    landing_pages = paginate(
      ::SiteCustomization::Page
        .landing
        .includes(:translations, **ATTACHMENTS.keys.to_h { ["#{it}_attachment".to_sym, :blob] })
        .order(:landing_nav_position, :id)
    )

    render json: {
      data: { landing_pages: landing_pages.map { serialize(it) } },
      pagination: pagination_meta(landing_pages)
    }
  end

  def show
    render json: { data: { landing_page: serialize(@landing_page) } }
  end

  def create
    landing_page = ::SiteCustomization::Page.new(landing: true, status: "draft")

    write_landing_page(landing_page, success_status: :created)
  end

  def update
    write_landing_page(@landing_page, success_status: :ok)
  end

  def destroy
    if @landing_page.safe_to_destroy?
      @landing_page.destroy!

      render json: { data: { message: "Landing page deleted" } }
    else
      render_invalid_values("base" => ["belongs to a projekt and cannot be deleted"])
    end
  end

  private

    def find_landing_page
      @landing_page = ::SiteCustomization::Page.landing.find(params[:id])
    end

    def write_landing_page(landing_page, success_status:)
      errors = {}
      attributes = parsed_attributes(landing_page_params, errors)
      translations = sanitize_translated_html(
        permitted_translations(translations_param, TRANSLATED_ATTRIBUTES), "content"
      )
      errors.merge!(unsupported_locales_error(translations_param) || {})
      uploaded_files = decoded_uploads(errors)
      removed_names = attachments_to_remove(uploaded_files.keys, errors)

      if errors.any?
        return render_invalid_values(errors)
      end

      previous_blobs = attached_blobs(landing_page)
      landing_page.assign_attributes(attributes.merge(uploaded_files))
      assign_translations(landing_page, translations)

      if save_with_translations(landing_page, translations)
        audit_uploads(landing_page, uploaded_files.keys, previous_blobs)
        remove_attachments(landing_page, removed_names, previous_blobs)

        render json: { data: { landing_page: serialize(landing_page.reload) } }, status: success_status
      else
        render_translated_record_errors(landing_page)
      end
    end

    def landing_page_params
      params.require(:landing_page).permit(*ATTRIBUTE_DEFINITIONS.keys)
    end

    def translations_param
      params.dig(:landing_page, :translations)
    end

    # An emptied navigation link colour goes back to the default black.
    def parsed_attributes(raw_attributes, errors)
      attribute_values, attribute_errors = parse_typed_attributes(raw_attributes.to_h, ATTRIBUTE_DEFINITIONS)
      errors.merge!(attribute_errors)

      if attribute_values.key?("landing_navigation_link_color")
        attribute_values["landing_navigation_link_color"] ||= DEFAULT_NAVIGATION_LINK_COLOR
      end

      attribute_values
    end

    def decoded_uploads(errors)
      attachments_param = params.dig(:landing_page, :attachments)
      return {} if attachments_param.nil?

      if !attachments_param.is_a?(ActionController::Parameters)
        errors["attachments"] = ["must be an object of base64 files keyed by attachment name"]

        return {}
      end

      attachments_param.to_unsafe_h.each_with_object({}) do |(name, encoded_file), uploads|
        if !ATTACHMENTS.key?(name)
          errors["attachments.#{name}"] = ["is not a landing page attachment"]
        elsif !encoded_file.is_a?(String) || encoded_file.blank?
          errors["attachments.#{name}"] = ["must be a base64 file or data URI"]
        else
          upload = decoded_attachment(encoded_file, name)

          if IMAGE_ATTACHMENT_NAMES.include?(name) && !image_file?(upload[:io])
            errors["attachments.#{name}"] = ["must be a JPEG, PNG or WebP image"]
          else
            uploads[name] = upload
          end
        end
      end
    end

    # Judged by the file content, not by the type a data URI claims.
    def image_file?(io)
      content_type = Marcel::MimeType.for(io)
      io.rewind

      IMAGE_CONTENT_TYPES.include?(content_type)
    end

    def attachments_to_remove(uploaded_names, errors)
      removal_param = params.dig(:landing_page, :remove_attachments)
      return [] if removal_param.nil?

      removed_names = Array(removal_param).map(&:to_s)
      unknown_names = removed_names - ATTACHMENTS.keys
      conflicting_names = removed_names & uploaded_names

      if unknown_names.any?
        errors["remove_attachments"] = ["contain unknown attachments: #{unknown_names.join(", ")}"]
      elsif conflicting_names.any?
        errors["remove_attachments"] = [
          "cannot remove an attachment uploaded in the same request: #{conflicting_names.join(", ")}"
        ]
      end

      removed_names & ATTACHMENTS.keys
    end

    def attached_blobs(landing_page)
      ATTACHMENTS.to_h do |name, attachment_reader|
        attachment = attachment_reader.call(landing_page)

        [name, attachment.attached? ? attachment.blob : nil]
      end
    end

    def audit_uploads(landing_page, uploaded_names, previous_blobs)
      uploaded_names.each do |name|
        current_blob = ATTACHMENTS.fetch(name).call(landing_page).blob

        audit_attachment_change(landing_page, name, previous_blobs[name], current_blob)
      end
    end

    def remove_attachments(landing_page, removed_names, previous_blobs)
      removed_names.each do |name|
        next if previous_blobs[name].nil?

        ATTACHMENTS.fetch(name).call(landing_page).purge
        audit_attachment_change(landing_page, name, previous_blobs[name], nil)
      end
    end

    def serialize(landing_page)
      {
        id: landing_page.id,
        slug: landing_page.slug,
        url: landing_page.url,
        status: landing_page.status,
        published_at: landing_page.published_at,
        landing_nav_position: landing_page.landing_nav_position,
        landing_show_in_top_nav: landing_page.landing_show_in_top_nav,
        landing_hide_title_and_subtitle: landing_page.landing_hide_title_and_subtitle,
        landing_site_logo_follow_to_landing_page: landing_page.landing_site_logo_follow_to_landing_page,
        landing_navigation_link_color: landing_page.landing_navigation_link_color,
        brand_color: landing_page.brand_color,
        projekt_id: landing_page.projekt_id,
        translations: serialize_translations(landing_page, TRANSLATED_ATTRIBUTES),
        attachments: ATTACHMENTS.to_h do |name, attachment_reader|
          [name, serialize_attachment(attachment_reader.call(landing_page))]
        end,
        created_at: landing_page.created_at,
        updated_at: landing_page.updated_at
      }
    end
end
