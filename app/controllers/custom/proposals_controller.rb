require_dependency Rails.root.join("app", "controllers", "proposals_controller").to_s

class ProposalsController

  before_action :authenticate_user!, except: [:index, :show, :map, :summary, :json_data]
  before_action :process_tags, only: [:create, :update]

  
  def all_proposal_map_locations
    ids = if params[:search]
      Proposal.search(params[:search]).pluck(:id)
    elsif params[:tags]
      Proposal.not_archived.published.tagged_with(params[:tags].split(","), all: true)
    else
      Proposal.not_archived.published.pluck(:id)
    end
    MapLocation.where(proposal_id: ids).map(&:json_data)
  end

  def index_customization
    discard_draft
    discard_archived
    load_retired
    load_selected
    load_featured
    remove_archived_from_order_links
    take_only_by_tag_names
    @proposals_coordinates = all_proposal_map_locations
  end

  def json_data
    proposal = Proposal.find(params[:id])
    data = {
      proposal_id: proposal.id,
      proposal_title: proposal.title
    }.to_json

    respond_to do |format|
      format.json { render json: data }
    end
  end

  private
    def process_tags
      params[:proposal][:tag_list_categories].split(",").each do |t|
        next if t.strip.blank?
        Tag.find_or_create_by name: t.strip, kind: :category
      end
      params[:proposal][:tag_list_subcategories].split(",").each do |t|
        next if t.strip.blank?
        Tag.find_or_create_by name: t.strip, kind: :subcategory
      end
      params[:proposal][:tag_list] ||= ""
      params[:proposal][:tag_list] += ((params[:proposal][:tag_list_categories] || "").split(",") + (params[:proposal][:tag_list_subcategories] || "").split(",")).join(",")
      params[:proposal][:tag_list_categories], params[:proposal][:tag_list_subcategories] = nil, nil
    end

    def take_only_by_tag_names
      if params[:tags].present?
        @resources = @resources.tagged_with(params[:tags].split(","), all: true)
        @subcategories = @resources.tag_counts.subcategory
      end
    end
end