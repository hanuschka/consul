class Admin::ProjektPhases::UserResourceCriteriaController < Admin::BaseController
  before_action :load_projekt_phase

  def index
    @criteria = @projekt_phase.user_resource_criteria
  end

  def create
    @criterion = @projekt_phase.user_resource_criteria.build(criterion_params)
    @criterion.position = @projekt_phase.user_resource_criteria.maximum(:position).to_i + 1
    if @criterion.save
      render json: { id: @criterion.id, text: @criterion.text }, status: :created
    else
      render json: { errors: @criterion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @criterion = @projekt_phase.user_resource_criteria.find(params[:criterion_id])
    if @criterion.update(criterion_params)
      head :ok
    else
      render json: { errors: @criterion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @projekt_phase.user_resource_criteria.find(params[:criterion_id]).destroy
    head :no_content
  end

  def reorder
    params[:order].each_with_index do |id, index|
      @projekt_phase.user_resource_criteria.where(id:).update_all(position: index)
    end
    head :ok
  end

  private

    def load_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:id])
    end

    def criterion_params
      params.require(:user_resource_criterion).permit(:text)
    end
end
