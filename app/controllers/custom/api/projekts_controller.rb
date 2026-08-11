class Api::ProjektsController < Api::BaseController
  include MapLocationAttributes
  include ImageAttributes
  include Translatable

  before_action :find_projekt, only: [:show, :update, :destroy, :update_setting, :update_settings, :update_page, :update_page_image, :update_body]

  DEFAULT_PROJEKTS_PER_PAGE = 20

  SORTABLE_COLUMNS = %w[
    created_at total_duration_start total_duration_end
    order_number name published_at page_title
  ].freeze

  DEFAULT_SORT_COLUMN = "created_at"

  PAGE_TITLE_SORT_LOCALE = "de"

  PAGE_TITLE_SORT_JOIN =
    "LEFT JOIN site_customization_pages scp_sort " \
    "ON scp_sort.projekt_id = projekts.id " \
    "LEFT JOIN site_customization_page_translations spt_sort " \
    "ON spt_sort.site_customization_page_id = scp_sort.id " \
    "AND spt_sort.locale = '#{PAGE_TITLE_SORT_LOCALE}'"

  SORT_EXPRESSIONS = {
    "name" => "LOWER(projekts.name)",
    "page_title" => "LOWER(spt_sort.title)"
  }.freeze

  def index
    check_read_access!

    only_public =
      if current_client.public_data?
        true
      else
        params[:only_public] != 'false'
      end

    if only_public
      projekts =
        Projekt
          .activated
          .with_published_custom_page
          .show_in_overview_page
    else
      projekts = Projekt.regular
    end

    valid_filters = %w[index_order_all index_order_underway index_order_ongoing index_order_upcoming index_order_expired index_order_individual_list]
    valid_filters.push("index_order_drafts") if current_client.admin?
    current_filter = valid_filters.include?(params[:filter]) ? params[:filter] : "index_order_all"
    projekts = projekts.send(current_filter)

    include_phases = params[:include_phases] == 'true'
    include_content_blocks = params[:include_content_blocks] == 'true'
    include_text = params[:include_text] != 'false'
    include_projekt_settings = params[:include_projekt_settings] == 'true'

    includes_hash = {}
    includes_hash[:projekt_settings] = {} if include_projekt_settings
    includes_hash[:content_blocks] = {} if include_text || include_content_blocks
    includes_hash[:page] = { translations: {}, image: { attachment_attachment: :blob }}

    if include_phases
      includes_hash[:projekt_phases] = [
        :settings,
        :individual_group_values,
        :geozone_restrictions
      ]
    end

    projekts = sort_projekts(projekts)

    paginating = params[:page].present? || params[:per_page].present?

    if paginating
      projekts = paginate(projekts, default_per_page: DEFAULT_PROJEKTS_PER_PAGE)
    end

    projekts = eager_load_projekt_associations(projekts, includes_hash)

    serailized_projekts = ProjektSerializer.serialize_collection(
      projekts,
      include_phases: include_phases,
      include_content_blocks: include_content_blocks,
      include_text: include_text,
      include_projekt_settings: include_projekt_settings,
      image_variant_versions: image_variant_versions,
      current_api_client: current_client
    )

    response = { data: { projekts: serailized_projekts } }

    response[:pagination] =
      if paginating
        pagination_meta(projekts)
      else
        no_pagination_meta
      end

    render json: response
  end

  def show
    check_read_access!

    if current_client.public_data?
      page_published = @projekt.page&.status == 'published'
      show_in_overview = @projekt.projekt_settings.find_by(key: 'projekt_feature.general.show_in_overview_page')&.value == 'active'

      unless @projekt.activated? && page_published && show_in_overview
        return render json: { error: { type: 'forbidden', messages: ['Access denied'] } }, status: 403
      end
    end

    include_phases = params[:include_phases] == 'true'
    include_content_blocks = params[:include_content_blocks] == 'true'

    serailized_projekt = ProjektSerializer.new(
      @projekt,
      include_phases: include_phases,
      include_content_blocks: include_content_blocks,
      current_api_client: current_client
    ).serialize

    render json: { data: { projekt: serailized_projekt } }
  end

  def create
    check_admin_access!
    projekt = Projekt.new(projekt_params)

    if projekt.save
      Projekt.ensure_order_integrity
      process_image_with_base64(projekt.page, params[:projekt][:image_attributes])

      create_default_content_block(projekt)

      serailized_projekt = ProjektSerializer.new(projekt).serialize

      render json: { data: { projekt: serailized_projekt } }, status: 201
    else
      render json: { error: { messages: projekt.errors.messages }}, status: 422
    end
  end

  def update
    check_admin_access!
    if @projekt.update(projekt_params)
      Projekt.ensure_order_integrity

      serailized_projekt = ProjektSerializer.new(@projekt).serialize

      render json: { data: { projekt: serailized_projekt } }
    else
      render json: { error: { messages: @projekt.errors.messages }}, status: 422
    end
  end

  def update_page
    check_admin_access!
    if @projekt.page.update(projekt_page_params)
      process_image_with_base64(@projekt.page, params[:projekt][:image_attributes])
      serailized_projekt = ProjektSerializer.new(@projekt).serialize

      render json: { data: { projekt: serailized_projekt } }
    else
      render json: { error: { messages: @projekt.page.errors.full_messages } }, status: 422
    end
  end

  def update_page_image
    check_admin_access!

    image_data = params[:projekt]&.dig(:image_attributes)

    if image_data.blank? || image_data[:attachment].blank?
      return render json: { error: { messages: ["No image provided"] } }, status: 422
    end

    process_image_with_base64(@projekt.page, image_data)

    render json: { data: { projekt: ProjektSerializer.new(@projekt).serialize } }
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def destroy
    check_admin_access!
    if @projekt.destroy
      @projekt.children.each do |child|
        child.update(parent: nil)
      end

      render json: { message: "Projekt destroyed"}
    else
      render json: { error: { messages: @projekt.errors.messages  } }, status: 422
    end
  end

  def update_setting
    check_admin_access!
    setting = @projekt.projekt_settings.find_by(key: setting_params[:key])

    unless setting
      return render json: { error: { messages: ["Setting not found"] } }, status: 404
    end

    if setting.update(value: setting_params[:value])
      render json: {
        data: {
          setting: {
            id: setting.id,
            key: setting.key,
            value: setting.value,
            projekt_id: setting.projekt_id
          }
        },
        message: "Setting updated successfully"
      }
    else
      render json: { error: { messages: setting.errors.full_messages } }, status: 422
    end
  end

  def update_settings
    check_admin_access!
    settings_hash = params[:settings]

    if settings_hash.blank?
      return render json: { error: { messages: ["settings parameter is required"] } }, status: 422
    end

    updated = []
    errors = {}

    settings_hash.each do |key, value|
      setting = @projekt.projekt_settings.find_by(key: key)

      if setting.blank?
        errors[key] = ["Setting not found"]
        next
      end

      if setting.update(value: value.to_s)
        updated << key
      else
        errors[key] = setting.errors.full_messages
      end
    end

    render json: { data: { updated: updated, errors: errors } }
  end

  def update_body
    check_admin_access!

    first_content_block = @projekt.content_blocks.order(:position).first

    unless first_content_block
      return render json: { error: { messages: ["No content block found for this project"] } }, status: 404
    end

    if first_content_block.update(content_block_body_params)
      serialized_content_block = ContentBlockSerializer.new(first_content_block).serialize

      render json: {
        data: { content_block: serialized_content_block },
        message: "Content block body updated successfully"
      }
    else
      render json: { error: { messages: first_content_block.errors.full_messages } }, status: 422
    end
  end

  private

  def sort_projekts(projekts)
    apply_sort_join(projekts)
      .reorder(Arel.sql("#{sort_expression} #{sort_direction.upcase} NULLS LAST"))
  end

  def apply_sort_join(projekts)
    if sort_column == "page_title"
      return projekts.joins(PAGE_TITLE_SORT_JOIN)
    end

    projekts
  end

  def sort_column
    SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : DEFAULT_SORT_COLUMN
  end

  def sort_direction
    params[:sort_direction] == "desc" ? "desc" : "asc"
  end

  def sort_expression
    SORT_EXPRESSIONS[sort_column] || "projekts.#{sort_column}"
  end

  def image_variant_versions
    return nil if params[:image_variant_versions].blank?

    params[:image_variant_versions].to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def eager_load_projekt_associations(projekts, includes_hash)
    return projekts if includes_hash.blank?

    projekts.includes(includes_hash)
  end

  def projekt_params
    attributes = [
      :name, :parent_id, :total_duration_start, :total_duration_end,
      :show_start_date_in_frontend, :show_end_date_in_frontend,
      :geozone_affiliated, :order_number, :tag_list, :related_sdg_list, :landing_page_id, geozone_affiliation_ids: [], sdg_goal_ids: [],
      individual_group_value_ids: [],
      map_location_attributes: map_location_attributes,
      projekt_manager_assignments_attributes: [:id, :projekt_manager_id, :projekt_id, permissions: []]
    ]
    params.require(:projekt).permit(attributes, translation_params(Projekt))
  end

  def projekt_page_params
    params.require(:page).permit(
      :title, :subtitle
    )
  end

  def process_tags
    if params[:projekt].present?
      params[:projekt][:tag_list] = (params[:projekt][:tag_list_predefined] || @projekt.tag_list.join(","))
      params[:projekt].delete(:tag_list_predefined)
    end
  end

  def map_location_params
    params.require(:projekt)
      .require(:map_location_attributes)
      .permit(map_location_attributes)
  end

  def find_projekt
    @projekt = Projekt
      .includes(
        :content_blocks,
        projekt_phases: [
          :settings,
          :individual_group_values,
          :geozone_restrictions
        ]
      )
      .find(params[:id])
  end

  def setting_params
    params.require(:setting).permit(:key, :value)
  end

  def content_block_body_params
    params.require(:projekt).permit(:body)
  end

  def create_default_content_block(projekt)
    # Create a blank content block for projects created through the API
    projekt.content_blocks.create!(
      name: "custom",
      locale: SiteCustomization::ContentBlock.canonical_locale,
      body: "",
      key: "projekt_content_block_#{projekt.id}_1_#{Time.now.to_i}",
      position: 1
    )
  end
end
