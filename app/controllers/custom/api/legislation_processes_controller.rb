class Api::LegislationProcessesController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:create]
  before_action :find_legislation_process, only: [:show, :update, :destroy]

  def create
    check_admin_access!
    legislation_process = Legislation::Process.new(legislation_process_params)
    legislation_process.projekt_phase = @projekt_phase

    if legislation_process.save
      serialized_legislation_process = LegislationProcessSerializer.new(legislation_process).serialize

      render json: { data: { legislation_process: serialized_legislation_process } }, status: 201
    else
      render json: { error: { messages: legislation_process.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_legislation_process = LegislationProcessSerializer.new(@legislation_process).serialize

    render json: { data: { legislation_process: serialized_legislation_process } }
  end

  def update
    check_admin_access!
    if @legislation_process.update(legislation_process_params)
      serialized_legislation_process = LegislationProcessSerializer.new(@legislation_process).serialize

      render json: { data: { legislation_process: serialized_legislation_process } }
    else
      render json: { error: { messages: @legislation_process.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @legislation_process.destroy
      render json: { message: "Legislation process destroyed" }
    else
      render json: { error: { messages: @legislation_process.errors.messages } }, status: 422
    end
  end

  private

  def legislation_process_params
    params.require(:legislation_process).permit(
      :start_date,
      :end_date,
      :debate_start_date,
      :debate_end_date,
      :draft_publication_date,
      :allegations_start_date,
      :allegations_end_date,
      :result_publication_date,
      :debate_phase_enabled,
      :allegations_phase_enabled,
      :draft_publication_enabled,
      :result_publication_enabled,
      :published,
      **translation_params(Legislation::Process)
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::LegislationPhase.find(params[:projekt_phase_id])
  end

  def find_legislation_process
    @legislation_process = Legislation::Process.find(params[:id])
  end
end

