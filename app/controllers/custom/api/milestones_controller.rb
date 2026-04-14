class Api::MilestonesController < Api::BaseController
  before_action :find_projekt_phase, only: [:index]

  def index
    check_read_access!
    milestones = @projekt_phase.milestones
      .order_by_publication_date
      .page(params[:page])
      .per(params[:per_page] || DEFAULT_PER_PAGE)

    serialized_milestones = MilestoneSerializer.serialize_collection(milestones)

    render json: {
      data: { milestones: serialized_milestones },
      pagination: pagination_meta(milestones)
    }
  end

  private

  def find_projekt_phase
    @projekt_phase = ProjektPhase::MilestonePhase.find(params[:projekt_phase_id])
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
