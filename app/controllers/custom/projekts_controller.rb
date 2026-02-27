class ProjektsController < ApplicationController
  include CustomHelper
  include ProposalsHelper
  include Search
  include LandingPageResolvable

  skip_authorization_check
  before_action :raise_flag_feature_disabled, except: [:map_html]

  include ProjektControllerHelper

  def index
    landing_page_slug = params[:landing_page_slug] || params[:landing_page]
    if landing_page_slug.present?
      @landing_page =
        SiteCustomization::Page
          .published
          .landing
          .where(landing_show_projekts_overview: true)
          .find_by(slug: landing_page_slug)

      if @landing_page.nil?
        raise ActionController::RoutingError.new('Not Found')
      end

      set_landing_page_topbar_ui_variables(@landing_page)
    end

    base_projekts =
      if @landing_page.present?
        @landing_page.landing_projekts
      else
        Projekt.all
      end

    @projekts = base_projekts.regular.includes(:active_and_visible_projekt_phases)
    @projekts = @projekts.search(@search_terms) if @search_terms.present?

    @all_projekts = @projekts.index_order_all
    @special_projekt = Projekt.unscoped.find_by(special: true, special_name: "projekt_overview_page")

    @resource_name = "projekt"

    valid_filters = %w[index_order_all index_order_underway index_order_ongoing index_order_upcoming index_order_expired index_order_individual_list]
    valid_filters.push("index_order_drafts") if current_user&.administrator? || current_user&.projekt_manager?
    @active_projekts_filters = valid_filters.select { |filter| @projekts.send(filter).count > 0 }.presence || ["index_order_all"]
    @current_projekts_filter = valid_filters.include?(params[:filter]) ? params[:filter] : "index_order_all"
    @projekts = @projekts.send(@current_projekts_filter)
    convert_back_to_relation if @projekts.is_a?(Array)

    @geozones = Geozone.all.order(:name)
    @selected_geozone_affiliation = params[:geozone_affiliation] || "all_resources"
    @affiliated_geozones = (params[:affiliated_geozones] || "").split(",").map(&:to_i)
    take_by_geozone_affiliations unless @search_terms.present?

    @categories = @projekts.map { |p| p.tags.category }.flatten.uniq.compact.sort
    @tag_cloud = tag_cloud
    take_only_by_tag_names unless @search_terms.present?

    @used_phases = @projekts.flat_map(&:active_and_visible_projekt_phases).map(&:type).uniq.compact
    @phases = ProjektPhase.where(type: @used_phases).group_by(&:type).map { |type, phases| phases.first }.reject { |p| p.type == "ProjektPhase::DebatePhase" }.sort_by { |p| ProjektPhase::PROJEKT_PHASES_TYPES.index(p.type) || 999 }
    @selected_phase_type = params[:phase_type] || 'all_phases'
    take_by_phase_type unless @search_terms.present?

    @sdgs = (@projekts.map(&:sdg_goals).flatten.uniq.compact + SDG::Goal.where(code: @filtered_goals).to_a).uniq
    @sdg_targets = (@projekts.map(&:sdg_targets).flatten.uniq.compact + SDG::Target.where(code: @filtered_targets).to_a).uniq
    @filtered_goals = params[:sdg_goals].present? ? params[:sdg_goals].split(',').map{ |code| code.to_i } : nil
    @filtered_targets = params[:sdg_targets].present? ? params[:sdg_targets].split(',')[0] : nil
    take_by_sdgs unless @search_terms.present?

    @show_comments = Setting["extended_feature.projekts_overview_page_footer.show_in_#{@current_projekts_filter}"].present?

    if @show_comments && @landing_page.present?
      @show_comments = false
    end

    if @show_comments
      set_variables_for_footer_comments
    end

    @projekts = @projekts.visible_for(current_user).sort_by_order_number
    @map_coordinates = all_projekts_map_locations(@projekts.pluck(:id))
    @projekts = Kaminari.paginate_array(@projekts).page(params[:page]).per(24)

    if Setting.new_design_enabled?
      render :index_new
    else
      render :index
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

  def update_selected_parent_projekt
    selected_parent_projekt_id = get_highest_unique_parent_projekt_id(params[:selected_projekts_ids])
    render json: {selected_parent_projekt_id: selected_parent_projekt_id }
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
      if @affiliated_geozones.present?
        @projekts = @projekts.joins(:geozone_affiliations).where(geozones: { id: @affiliated_geozones })
      else
        @projekts = @projekts.joins(:geozone_affiliations).where.not(geozones: { id: nil })
      end
    end
  end

  def take_by_phase_type
    return if @selected_phase_type == 'all_phases'

    projekt_ids = @projekts.joins(:active_and_visible_projekt_phases).where(projekt_phases: { type: @selected_phase_type }).pluck(:id).uniq
    @projekts = @projekts.where(id: projekt_ids)
  end

  def tag_cloud
    TagCloud.new(Projekt.all, params[:tags])
  end

  def raise_flag_feature_disabled
    raise FeatureFlags::FeatureDisabled, :projekts_overview unless Setting["extended_feature.projekts_overview_page_navigation.show_in_navigation"]
  end

  def set_variables_for_footer_comments
    @valid_orders = %w[most_voted newest oldest]
    @current_order = @valid_orders.include?(params[:order]) ? params[:order] : @valid_orders.first

    @commentable = Projekt.unscoped.find_by(special: true, special_name: "projekt_overview_page")
    @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
    set_comment_flags(@comment_tree.comments)
  end

  def convert_back_to_relation
    @projekts = Projekt.where(id: @projekts.pluck(:id))
  end
end
