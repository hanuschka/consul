class Api::ProjektArgumentsController < Api::BaseController
  include ImageAttributes

  before_action :find_projekt_phase, only: [:create]
  before_action :find_projekt_argument, only: [:show, :update, :destroy]

  def create
    projekt_argument = @projekt_phase.projekt_arguments.new(projekt_argument_params)

    if projekt_argument.save
      serialized_projekt_argument = ProjektArgumentSerializer.new(projekt_argument).serialize

      render json: { data: { projekt_argument: serialized_projekt_argument } }, status: 201
    else
      render json: { error: { messages: projekt_argument.errors.full_messages } }, status: 422
    end
  end

  def update
    if @projekt_argument.update(projekt_argument_params)
      serialized_projekt_argument = ProjektArgumentSerializer.new(@projekt_argument).serialize

      render json: { data: { projekt_argument: serialized_projekt_argument } }
    else
      render json: { error: { messages: @projekt_argument.errors.full_messages } }, status: 422
    end
  end

  def destroy
    if @projekt_argument.destroy
      render json: { message: "Projekt argument destroyed" }
    else
      render json: { error: { messages: @projekt_argument.errors.messages } }, status: 422
    end
  end

  private

  def projekt_argument_params
    params.require(:projekt_argument).permit(
      :name,
      :position,
      :note,
      :pro,
      image_attributes: image_attributes
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::ArgumentPhase.find(params[:projekt_phase_id])
  end

  def find_projekt_argument
    @projekt_argument = ProjektArgument.find(params[:id])
  end
end

