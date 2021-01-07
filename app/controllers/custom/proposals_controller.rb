require_dependency Rails.root.join("app", "controllers", "proposals_controller").to_s

class ProposalsController
  def index_customization
    discard_draft
    discard_archived
    load_retired
    load_selected
    load_featured
    remove_archived_from_order_links
    take_only_by_tag_names
  end

  private
    def take_only_by_tag_names
      if params[:tags].present?
        @resources = @resources.tagged_with(params[:tags].split(","), all: true)
        @subcategories = @resources.tag_counts.subcategory
      end
    end
end