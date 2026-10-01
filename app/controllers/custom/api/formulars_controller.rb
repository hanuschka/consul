class Api::FormularsController < Api::BaseController
  DEFAULT_FORMULARS_PER_PAGE = 100

  before_action :find_projekt_phase, only: [:index, :create]
  before_action :find_formular, only: [:show, :update, :destroy]

  def index
    check_read_access!
    formulars = paginate(
      Formular.where(projekt_phase_id: @projekt_phase.id).order(:id),
      default_per_page: DEFAULT_FORMULARS_PER_PAGE
    )

    serialized_formulars = formulars.map { |formular| FormularSerializer.new(formular).serialize }

    render json: {
      data: { formulars: serialized_formulars },
      pagination: pagination_meta(formulars)
    }
  end

  def create
    check_admin_access!
    formular = Formular.new(formular_params)
    formular.projekt_phase = @projekt_phase

    if formular.save
      serialized_formular = FormularSerializer.new(formular).serialize

      render json: { data: { formular: serialized_formular } }, status: 201
    else
      render json: { error: { messages: formular.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_formular = FormularSerializer.new(@formular).serialize

    render json: { data: { formular: serialized_formular } }
  end

  def update
    check_admin_access!
    if @formular.update(formular_params)
      serialized_formular = FormularSerializer.new(@formular).serialize

      render json: { data: { formular: serialized_formular } }
    else
      render json: { error: { messages: @formular.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @formular.destroy
      render json: { message: "Formular destroyed" }
    else
      render json: { error: { messages: @formular.errors.messages } }, status: 422
    end
  end

  private

  def formular_params
    # Formular has no editable attributes besides projekt_phase association
    {}
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::FormularPhase.find(params[:projekt_phase_id])
  end

  def find_formular
    @formular = Formular.find(params[:id])
  end
end
