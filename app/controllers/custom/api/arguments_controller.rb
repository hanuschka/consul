class Api::ArgumentsController < Api::BaseController
  include ImageAttributes

  before_action :find_projekt_phase, only: [:index, :create]
  before_action :find_projekt_argument, only: [:show, :update, :destroy]

  def index
    check_read_access!

    arguments = paginate(@projekt_phase.projekt_arguments)

    serialized_arguments = ArgumentSerializer.serialize_collection(arguments)

    render json: {
      data: { arguments: serialized_arguments },
      pagination: pagination_meta(arguments)
    }
  end

  def create
    check_admin_access!
    projekt_argument = @projekt_phase.projekt_arguments.new(projekt_argument_params)

    if projekt_argument.save
      process_image_with_base64(projekt_argument, params[:projekt_argument][:image_attributes])

      serialized_projekt_argument = ArgumentSerializer.new(projekt_argument).serialize

      render json: { data: { projekt_argument: serialized_projekt_argument } }, status: 201
    else
      render json: { error: { messages: projekt_argument.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def show
    check_read_access!
    serialized_projekt_argument = ArgumentSerializer.new(@projekt_argument).serialize

    render json: { data: { projekt_argument: serialized_projekt_argument } }
  end

  def update
    check_admin_access!
    if @projekt_argument.update(projekt_argument_params)
      process_image_with_base64(@projekt_argument, params[:projekt_argument][:image_attributes])

      serialized_projekt_argument = ArgumentSerializer.new(@projekt_argument).serialize

      render json: { data: { projekt_argument: serialized_projekt_argument } }
    else
      render json: { error: { messages: @projekt_argument.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def destroy
    check_admin_access!
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
      :pro
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::ArgumentPhase.find(params[:projekt_phase_id])
  end

  def find_projekt_argument
    @projekt_argument = ProjektArgument.find(params[:id])
  end
end

