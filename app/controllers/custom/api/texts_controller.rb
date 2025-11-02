class Api::TextsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:create]
  before_action :find_text, only: [:show, :update, :destroy]

  def create
    check_admin_access!
    text = Legislation::Process.new(text_params)
    text.projekt_phase = @projekt_phase

    if text.save
      serialized_text = LegislationProcessSerializer.new(text).serialize

      render json: { data: { text: serialized_text } }, status: 201
    else
      render json: { error: { messages: text.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_text = LegislationProcessSerializer.new(@text).serialize

    render json: { data: { text: serialized_text } }
  end

  def update
    check_admin_access!
    if @text.update(text_params)
      serialized_text = LegislationProcessSerializer.new(@text).serialize

      render json: { data: { text: serialized_text } }
    else
      render json: { error: { messages: @text.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @text.destroy
      render json: { message: "Text destroyed" }
    else
      render json: { error: { messages: @text.errors.messages } }, status: 422
    end
  end

  private

  def text_params
    params.require(:text).permit(
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

  def find_text
    @text = Legislation::Process.find(params[:id])
  end
end
