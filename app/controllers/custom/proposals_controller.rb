require_dependency Rails.root.join("app", "controllers", "proposals_controller").to_s

class ProposalsController

  include ProposalsHelper

  before_action :authenticate_user!, except: [:index, :show, :map, :summary, :json_data]
  before_action :process_tags, only: [:create, :update]

  def index_customization
    @selected_tags = params[:tags]&.split(",")&.map {|tt| t2 = Tag.find_by(name: tt)}&.compact || []
    @project_tag = @selected_tags&.map {|tt| tt&.kind == 'project' ? tt : nil}.compact.first
    @projects = ActsAsTaggableOn::Tag.project
    unless @project_tag
      url_tags = params[:tags]&.split(",") || []
      url_tags << ActsAsTaggableOn::Tag.general_project.name
      prms = params.to_unsafe_h
      prms[:tags] = url_tags.join(",")
      redirect_to(prms) and return
    end
    discard_draft
    discard_archived
    load_retired
    load_selected
    load_featured
    remove_archived_from_order_links
    take_only_by_tag_names
    @proposals_coordinates = all_proposal_map_locations
  end

  private
    def process_tags
      if params[:proposal][:tags]
        params[:tags] = params[:proposal][:tags].split(',')
        params[:proposal].delete(:tags)
      end

      params[:proposal][:tag_list_custom]&.split(",")&.each do |t|
        next if t.strip.blank?
        Tag.find_or_create_by name: t.strip
      end
      params[:proposal][:tag_list] ||= ""
      params[:proposal][:tag_list] += ((params[:proposal][:tag_list_predefined] || "").split(",") + (params[:proposal][:tag_list_custom] || "").split(",")).join(",")
      params[:proposal].delete(:tag_list_predefined)
      params[:proposal].delete(:tag_list_custom)
    end

    def take_only_by_tag_names
      if params[:tags].present?
        @resources = @resources.tagged_with(params[:tags].split(","), all: true)
        @subcategories = @resources.tag_counts.subcategory
      end
    end
end

