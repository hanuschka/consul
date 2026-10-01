class Api::MilestoneStatusesController < Api::BaseController
  before_action :find_milestone, only: [:create], if: -> { params[:milestone_id].present? }
  before_action :find_milestone_status, only: [:show, :update, :destroy]

  def index
    check_read_access!

    milestone_statuses = paginate(Milestone::Status.all)

    serialized_statuses = MilestoneStatusSerializer.serialize_collection(milestone_statuses)

    render json: {
      data: { milestone_statuses: serialized_statuses },
      pagination: pagination_meta(milestone_statuses)
    }
  end

  def create
    check_admin_access!

    milestone_status = Milestone::Status.new(milestone_status_params)

    if milestone_status.save
      serialized_status = MilestoneStatusSerializer.new(milestone_status).serialize

      render json: { data: { milestone_status: serialized_status } }, status: 201
    else
      render json: { error: { messages: milestone_status.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_status = MilestoneStatusSerializer.new(@milestone_status).serialize

    render json: { data: { milestone_status: serialized_status } }
  end

  def update
    check_admin_access!
    @milestone_status.assign_attributes(milestone_status_params)

    if @milestone_status.save
      serialized_status = MilestoneStatusSerializer.new(@milestone_status).serialize

      render json: { data: { milestone_status: serialized_status } }
    else
      render json: { error: { messages: @milestone_status.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @milestone_status.destroy
      render json: { message: "Milestone status destroyed" }
    else
      render json: { error: { messages: @milestone_status.errors.messages } }, status: 422
    end
  end

  private

  def milestone_status_params
    params.require(:milestone_status).permit(:name)
  end

  def find_milestone
    Milestone.find(params[:milestone_id])
  end

  def find_milestone_status
    @milestone_status = Milestone::Status.find(params[:id])
  end
end
