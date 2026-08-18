class ProjektsController < ApplicationController
  # Attached only to the paginated page, so this graph is built for the 24
  # rendered projekts rather than for every match. The category and phase
  # facets no longer walk the records at all (ProjektIndexFacetsQuery).
  LIST_ITEM_PRELOADS = [
    :projekt_settings,
    :tags,
    { page: [:image, :translations] },
    { active_and_visible_projekt_phases: [:translations, :settings] },
    { sdg_relations: :related_sdg }
  ].freeze

  # The SDG facets are still derived in Ruby, so they remain the one part of
  # the request that loads every matching projekt. They stay this way because
  # the target dropdown renders them in projekt order, which an aggregate
  # query would not reproduce. Preloading only these three keeps that ordering
  # without also pulling the list-item graph for every match.
  SDG_FACET_PRELOADS = [:sdg_goals, :sdg_global_targets, :sdg_local_targets].freeze

  # Maps each filter name to the scope that applies it. Insertion order is the
  # order the filter chips render in. Kept as explicit lambdas so no filter is
  # ever reached through `send` on a param.
  INDEX_FILTERS = {
    "index_order_all" => ->(projekts) { projekts.index_order_all },
    "index_order_underway" => ->(projekts) { projekts.index_order_underway },
    "index_order_ongoing" => ->(projekts) { projekts.index_order_ongoing },
    "index_order_upcoming" => ->(projekts) { projekts.index_order_upcoming },
    "index_order_expired" => ->(projekts) { projekts.index_order_expired },
    "index_order_individual_list" => ->(projekts) { projekts.index_order_individual_list }
  }.freeze

  DRAFTS_INDEX_FILTER = {
    "index_order_drafts" => ->(projekts) { projekts.index_order_drafts }
  }.freeze

  include CustomHelper
  include ProposalsHelper
  include Search
  include LandingPageResolvable

  skip_authorization_check
  before_action :raise_flag_feature_disabled, except: [:map_html]

  include ProjektControllerHelper

  def index
    resolve_landing_page_from_slug

    base_projekts =
      if @landing_page.present?
        @landing_page.landing_projekts
      else
        Projekt.all
      end

    @projekts = base_projekts.regular
    @projekts = @projekts.search(@search_terms) if @search_terms.present?

    @all_projekts = @projekts.index_order_all
    @special_projekt = Projekt.unscoped.find_by(special: true, special_name: "projekt_overview_page")

    @resource_name = "projekt"

    index_filters = available_index_filters
    @active_projekts_filters = index_filters.select { |_name, filter| filter.call(@projekts).exists? }.keys.presence || ["index_order_all"]
    @current_projekts_filter = index_filters.key?(params[:filter]) ? params[:filter] : "index_order_all"
    @projekts = index_filters.fetch(@current_projekts_filter).call(@projekts)

    @districts = RegisteredAddress::District.all.sort_by(&:name_for_display)
    @geozones = @districts.empty? ? Geozone.order(:name).to_a : []
    @selected_geozone_affiliation = params[:geozone_affiliation] || "all_resources"
    @affiliated_districts = (params[:affiliated_districts] || "").split(",").map(&:to_i)
    @affiliated_geozones = (params[:affiliated_geozones] || "").split(",").map(&:to_i)
    take_by_geozone_affiliations if @search_terms.blank?

    @categories = ProjektIndexFacetsQuery.category_tags(@projekts)
    take_only_by_tag_names if @search_terms.blank?

    @used_phases = ProjektIndexFacetsQuery.phase_types(@projekts)
    @phases = ProjektPhase.where(type: @used_phases).group_by(&:type).map { |type, phases| phases.first }.reject { |p| p.type == "ProjektPhase::DebatePhase" }.sort_by { |p| ProjektPhase::PROJEKT_PHASES_TYPES.index(p.type) || 999 }
    @selected_phase_type = params[:phase_type] || 'all_phases'
    take_by_phase_type if @search_terms.blank?

    sdg_facet_projekts = @projekts.preload(SDG_FACET_PRELOADS).to_a
    @sdgs = (sdg_facet_projekts.map(&:sdg_goals).flatten.uniq.compact + SDG::Goal.where(code: @filtered_goals).to_a).uniq
    @sdg_targets = (sdg_facet_projekts.map(&:sdg_targets).flatten.uniq.compact + SDG::Target.where(code: @filtered_targets).to_a).uniq
    @filtered_goals = params[:sdg_goals].present? ? params[:sdg_goals].split(',').map{ |code| code.to_i } : nil
    @filtered_targets = params[:sdg_targets].present? ? params[:sdg_targets].split(',')[0] : nil
    take_by_sdgs if @search_terms.blank?

    @show_comments = Setting["extended_feature.projekts_overview_page_footer.show_in_#{@current_projekts_filter}"].present?

    if @show_comments && @landing_page.present?
      @show_comments = false
    end

    if @show_comments
      set_variables_for_footer_comments
    end

    @projekts = @projekts.visible_for(current_user).reorder("projekts.created_at DESC").sort_by_order_number
    @map_coordinates = all_projekts_map_locations(@projekts.pluck(:id).uniq)
    @projekts = @projekts.distinct.page(params[:page]).per(24).preload(LIST_ITEM_PRELOADS)

    respond_to do |format|
      format.html do
        if Setting.new_design_enabled?
          render :index_new
        else
          render :index
        end
      end
    end
  end

  def footer_comments
    set_variables_for_footer_comments
  end

  def show
    projekt = Projekt.find(params[:id])

    redirect_to page_path(projekt.page.slug) if projekt.present?
  rescue
    head 404, content_type: "text/html"
  end

  def json_data
    @projekt = Projekt.find(params[:id])

    image_url = url_for @projekt.image.attachment.variant(
                  resize_to_fill: MapLocation::MAP_POPUP_STANDARD_IMAGE_SIZE,
                  format: "jpeg",
                  saver: { strip: true, interlace: "JPEG", quality: 80 }
                ) if @projekt.image&.attachment&.attached?

    data = {
      resource_type: "projekt",
      id: @projekt.id,
      title: @projekt.title,
      image_url: image_url,
      tags: @projekt.tags.pluck(:name),
      sdg_goals: @projekt.sdg_goals.map { |goal| { code: goal.code, title: goal.title, image: "sdg/goal_#{goal.code}.png"} }
    }.to_json

    respond_to do |format|
      format.json { render json: data }
    end
  end

  def map_html
    @projekt = Projekt.find(params[:id])
  end

  private

  def available_index_filters
    return INDEX_FILTERS.merge(DRAFTS_INDEX_FILTER) if current_user&.administrator? || current_user&.projekt_manager?

    INDEX_FILTERS
  end

  def take_only_by_tag_names
    if params[:tags].present?
      @projekts = @projekts.tagged_with(params[:tags].split(","), all: true)
    end
  end

  def take_by_sdgs
    if params[:sdg_targets].present?
      sdg_target_codes = params[:sdg_targets].split(',')
      @projekts = @projekts.left_joins(sdg_global_targets: :local_targets)

      @projekts = @projekts.where(sdg_targets: { code: sdg_target_codes}).or(@projekts.where(sdg_local_targets: { code: sdg_target_codes }))
      return
    end

    if params[:sdg_goals].present?
      @projekts = @projekts.joins(:sdg_goals).where(sdg_goals: { code: params[:sdg_goals].split(',') })
    end
  end

  def take_by_geozone_affiliations
    case @selected_geozone_affiliation
    when 'all_resources'
      @projekts
    when 'no_affiliation'
      @projekts = @projekts.where(geozone_affiliated: 'no_affiliation')
    when 'entire_city'
      @projekts = @projekts.where(geozone_affiliated: 'entire_city')
    when 'only_geozones'
      @projekts = @projekts.where(geozone_affiliated: 'only_geozones')
      if @districts.any?
        if @affiliated_districts.present?
          @projekts = @projekts.joins(:registered_address_district_affiliations).where(registered_address_districts: { id: @affiliated_districts })
        else
          @projekts = @projekts.joins(:registered_address_district_affiliations).where.not(registered_address_districts: { id: nil })
        end
      else
        if @affiliated_geozones.present?
          @projekts = @projekts.joins(:geozone_affiliations).where(geozones: { id: @affiliated_geozones })
        else
          @projekts = @projekts.joins(:geozone_affiliations).where.not(geozones: { id: nil })
        end
      end
    end
  end

  def take_by_phase_type
    return if @selected_phase_type == 'all_phases'

    projekt_ids = @projekts.joins(:active_and_visible_projekt_phases).where(projekt_phases: { type: @selected_phase_type }).pluck(:id).uniq
    @projekts = @projekts.where(id: projekt_ids)
  end

  def raise_flag_feature_disabled
    raise FeatureFlags::FeatureDisabled, :projekts_overview unless Setting["process.projekts"].present?
  end

  def set_variables_for_footer_comments
    @valid_orders = %w[most_voted newest oldest]
    @current_order = @valid_orders.include?(params[:order]) ? params[:order] : @valid_orders.first

    @commentable = Projekt.unscoped.find_by(special: true, special_name: "projekt_overview_page")

    if @commentable.blank?
      @show_comments = false
      return
    end

    @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
    set_comment_flags(@comment_tree.comments)
  end
end
