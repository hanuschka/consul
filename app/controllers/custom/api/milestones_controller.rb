class Api::MilestonesController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:index, :create]

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

  def create
    check_admin_access!
    milestone = @projekt_phase.milestones.new(milestone_params)

    if milestone.save
      serialized_milestone = MilestoneSerializer.new(milestone).serialize

      render json: { data: { milestone: serialized_milestone } }, status: 201
    else
      render json: { error: { messages: milestone.errors.full_messages } }, status: 422
    end
  end

  private

  def milestone_params
    params.require(:milestone).permit(
      :title,
      :description,
      :custom_date,
      :publication_date,
      :status_id,
      translation_params(Milestone, only: [:title, :description, :custom_date])
    )
  end

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
